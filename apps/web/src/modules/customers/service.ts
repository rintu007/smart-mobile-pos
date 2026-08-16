import { Prisma } from "@prisma/client";
import * as identityService from "@/modules/identity/service";
import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import type { ConflictCursor, CustomerCursor, FieldConflictInput, PurchaseHistoryCursor } from "./repository";
import type { CreateCustomerRequest, UpdateCustomerRequest } from "./schema";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

const UNIQUE_CONSTRAINT_VIOLATION = "P2002";

function formatCustomer(customer: {
  id: string;
  name: string | null;
  phone: string | null;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: customer.id,
    name: customer.name,
    phone: customer.phone,
    created_at: customer.createdAt.toISOString(),
    updated_at: customer.updatedAt.toISOString(),
  };
}

/**
 * docs/modules/customers/specification.md#1a-sprint-32--customers-mobile-m3-item-2 — the
 * sanctioned cross-module existence check `pos/service.ts` calls for an optional `customer_id` on
 * `POST /sales`, service-to-service per layering-rules.md §2 (never a direct repository-to-table
 * reach-through the way `products/repository.ts`'s own `findCategoryById`/`findUnitById`
 * pre-existing shortcut does — that's a real, separately-noted inconsistency this function
 * deliberately doesn't copy).
 */
export async function customerExists(tenantId: string, id: string): Promise<boolean> {
  const customer = await repository.findCustomerById(tenantId, id);
  return customer !== null;
}

function assertHasIdentifier(name: string | null | undefined, phone: string | null | undefined) {
  if (!name && !phone) {
    throw new ApiError(
      422,
      "CUSTOMER_IDENTIFIER_REQUIRED",
      "At least one of name or phone is required.",
    );
  }
}

function translatePhoneConflict(error: unknown, phone: string | null | undefined): never {
  // customers.md's PHONE_ALREADY_ASSIGNED — the (tenant_id, phone) WHERE deactivated_at IS NULL
  // partial unique index's P2002, translated rather than surfaced as a generic 500, the same
  // pattern products/service.ts's own BARCODE_ALREADY_ASSIGNED translation already established.
  if (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === UNIQUE_CONSTRAINT_VIOLATION
  ) {
    throw new ApiError(
      409,
      "PHONE_ALREADY_ASSIGNED",
      `Phone ${phone} is already assigned to another customer.`,
    );
  }
  throw error;
}

/**
 * docs/modules/customers/specification.md#4-api-contract — POST /api/v1/customers.
 * Permission enforcement (Cashier+) is applied by the Route Handler's own `requirePermission`
 * call, not here.
 */
export async function createCustomer(
  authUserId: string,
  tenantId: string,
  input: CreateCustomerRequest,
) {
  assertHasIdentifier(input.name, input.phone);

  const createdBy = await identityService.resolveUserId(authUserId);

  let customer;
  try {
    customer = await repository.createCustomer({ ...input, tenantId, createdBy });
  } catch (error) {
    translatePhoneConflict(error, input.phone);
  }

  return formatCustomer(customer);
}

interface FieldMergeResult {
  applied: { name?: string | null; phone?: string | null };
  conflicts: { field: "name" | "phone"; currentValue: string | null; attemptedValue: string | null }[];
}

/**
 * docs/modules/customers/specification.md §1c — the field-level 3-way merge
 * (conflict-resolution.md §3) at the heart of this sprint. For each of `name`/`phone`: if the
 * request's own `base_<field>` equals its `<field>` value, this edit never intended to touch that
 * field at all — skipped entirely, regardless of what the current server value is (leaving whoever
 * else touched it, if anyone, untouched). Otherwise this edit *does* want to change the field:
 * `current === base` means nobody else changed it since this device's own base — applied outright;
 * `current === newValue` means someone already set it to exactly what this edit also wants — a
 * silent no-op, not a conflict; anything else is the genuine field-edit conflict this sprint exists
 * to detect, recorded rather than applied.
 *
 * `base_updated_at` is deliberately not consulted here — see schema.ts's own comment on why the
 * whole-row fast path conflict-resolution.md §3 describes is mathematically subsumed by this
 * per-field comparison, not a materially different code path.
 */
function mergeCustomerFields(
  current: { name: string | null; phone: string | null },
  input: UpdateCustomerRequest,
): FieldMergeResult {
  const applied: FieldMergeResult["applied"] = {};
  const conflicts: FieldMergeResult["conflicts"] = [];

  const fields: { key: "name" | "phone"; base: string | null; value: string | null }[] = [
    { key: "name", base: input.base_name, value: input.name },
    { key: "phone", base: input.base_phone, value: input.phone },
  ];

  for (const { key, base, value } of fields) {
    if (value === base) continue; // this edit doesn't intend to change this field.
    const currentValue = current[key];
    if (currentValue === base) {
      applied[key] = value;
    } else if (currentValue === value) {
      // Already matches what this edit wants — nothing to do, not a conflict.
      continue;
    } else {
      conflicts.push({ field: key, currentValue, attemptedValue: value });
    }
  }

  return { applied, conflicts };
}

/**
 * docs/modules/customers/specification.md#4-api-contract — PATCH /api/v1/customers/{id}, upgraded
 * Sprint 35 (§1c) to the merge-aware shape shared with the `customer.update` sync-push operation
 * (sync-api.md §1's "push calls the exact same service method as the direct endpoint" rule, held
 * intact rather than treated as an exception). `assertHasIdentifier` is checked against the
 * resulting merged state (applied fields plus whatever's left at its current, un-conflicted value).
 */
export async function updateCustomer(
  authUserId: string,
  tenantId: string,
  id: string,
  input: UpdateCustomerRequest,
) {
  const existing = await repository.findCustomerById(tenantId, id);
  if (!existing) {
    throw new ApiError(404, "NOT_FOUND", `Customer ${id} not found.`);
  }

  const { applied, conflicts } = mergeCustomerFields(existing, input);

  const mergedName = applied.name !== undefined ? applied.name : existing.name;
  const mergedPhone = applied.phone !== undefined ? applied.phone : existing.phone;
  assertHasIdentifier(mergedName, mergedPhone);

  const actorUserId = await identityService.resolveUserId(authUserId);

  let customer = existing;
  if (applied.name !== undefined || applied.phone !== undefined) {
    try {
      customer = await repository.updateCustomerFields(id, applied, actorUserId);
    } catch (error) {
      translatePhoneConflict(error, applied.phone);
    }
  }

  if (conflicts.length > 0) {
    // The already-applied value's own setter — the row's own `updatedBy` if it's ever been edited,
    // falling back to its creator otherwise (§1c's own named, accepted small-scale simplification:
    // attributes to the *most recent* editor, not necessarily the specific edit that touched this
    // exact field, correct for the realistic 2-device scenario this sprint's own exit criterion
    // describes).
    const currentSetBy = existing.updatedBy ?? existing.createdBy;
    const conflictInputs: FieldConflictInput[] = conflicts.map((conflict) => ({
      field: conflict.field,
      currentValue: conflict.currentValue,
      currentSetBy,
      attemptedValue: conflict.attemptedValue,
      attemptedSetBy: actorUserId,
    }));
    await repository.createFieldConflicts(tenantId, id, conflictInputs);
  }

  return formatCustomer(customer);
}

function formatConflict(conflict: {
  id: string;
  customerId: string;
  field: string;
  currentValue: string | null;
  attemptedValue: string | null;
  createdAt: Date;
  customer: { name: string | null; phone: string | null };
  currentSetByUser: { id: string; displayName: string };
  attemptedSetByUser: { id: string; displayName: string };
}) {
  return {
    id: conflict.id,
    customer_id: conflict.customerId,
    customer_name: conflict.customer.name ?? conflict.customer.phone,
    field: conflict.field,
    current_value: conflict.currentValue,
    current_set_by: { id: conflict.currentSetByUser.id, display_name: conflict.currentSetByUser.displayName },
    attempted_value: conflict.attemptedValue,
    attempted_set_by: {
      id: conflict.attemptedSetByUser.id,
      display_name: conflict.attemptedSetByUser.displayName,
    },
    created_at: conflict.createdAt.toISOString(),
  };
}

/**
 * docs/modules/customers/specification.md#4-api-contract — GET /api/v1/customers/conflicts.
 * Manager/Owner only (Route Handler's own `requirePermission`, not here).
 */
export async function listConflicts(tenantId: string, query: { cursor?: string; limit: number }) {
  const decodedCursor = query.cursor ? decodeConflictCursor(query.cursor) : null;
  const fetched = await repository.listUnresolvedConflicts(tenantId, decodedCursor, query.limit);
  const hasMore = fetched.length > query.limit;
  const rows = hasMore ? fetched.slice(0, query.limit) : fetched;
  const lastRow = rows[rows.length - 1];
  const nextCursor = hasMore && lastRow ? encodeConflictCursor(lastRow) : null;

  return {
    data: rows.map((conflict) => formatConflict(conflict)),
    next_cursor: nextCursor,
  };
}

/**
 * docs/modules/customers/specification.md#4-api-contract — POST /api/v1/customers/conflicts/{id}/resolve.
 * Idempotent no-op if already resolved (the same `approveReturn`/`deactivateCustomer`
 * already-decided-state-transition shape) — the *original* resolution stands even if a retry
 * supplies a different value, matching every other idempotent-replay convention in this codebase
 * (a replay never re-applies).
 */
export async function resolveConflict(
  authUserId: string,
  tenantId: string,
  id: string,
  resolvedValue: string | null,
) {
  const conflict = await repository.findConflictById(tenantId, id);
  if (!conflict) {
    throw new ApiError(404, "NOT_FOUND", `Conflict ${id} not found.`);
  }
  if (conflict.resolvedAt) {
    return formatConflict(conflict);
  }
  if (resolvedValue !== conflict.currentValue && resolvedValue !== conflict.attemptedValue) {
    throw new ApiError(
      422,
      "CONFLICT_RESOLUTION_VALUE_INVALID",
      "resolved_value must match one of this conflict's own candidate values.",
    );
  }

  const actorUserId = await identityService.resolveUserId(authUserId);
  const { conflict: resolved } = await repository.resolveConflict({
    conflictId: id,
    customerId: conflict.customerId,
    resolvedValue,
    resolvedBy: actorUserId,
  });

  return formatConflict({ ...resolved, customer: conflict.customer, currentSetByUser: conflict.currentSetByUser, attemptedSetByUser: conflict.attemptedSetByUser });
}

function encodeConflictCursor(row: ConflictCursor): string {
  return Buffer.from(`${row.createdAt.toISOString()}|${row.id}`).toString("base64url");
}

function decodeConflictCursor(cursor: string): ConflictCursor {
  const [createdAtIso, id] = decodeCursorParts(cursor);
  const createdAt = new Date(createdAtIso);
  if (Number.isNaN(createdAt.getTime()) || !id) {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }
  return { createdAt, id };
}

/**
 * docs/modules/customers/specification.md#4-api-contract — DELETE /api/v1/customers/{id}.
 * Idempotent: an already-deactivated customer returns its existing state unchanged, the same
 * short-circuit roles/service.ts's `deactivateUser` already established for the structurally
 * identical case.
 */
export async function deactivateCustomer(tenantId: string, id: string) {
  const existing = await repository.findCustomerById(tenantId, id);
  if (!existing) {
    throw new ApiError(404, "NOT_FOUND", `Customer ${id} not found.`);
  }
  if (existing.deactivatedAt) {
    return formatCustomer(existing);
  }

  const deactivated = await repository.deactivateCustomer(id);
  return formatCustomer(deactivated);
}

/**
 * docs/modules/customers/specification.md#4-api-contract — GET /api/v1/customers.
 */
export async function listCustomers(
  tenantId: string,
  query: { cursor?: string; limit: number; phone?: string },
) {
  const decodedCursor = query.cursor ? decodeCustomerCursor(query.cursor) : null;
  const fetched = await repository.listCustomers(
    tenantId,
    { phone: query.phone },
    decodedCursor,
    query.limit,
  );
  const hasMore = fetched.length > query.limit;
  const rows = hasMore ? fetched.slice(0, query.limit) : fetched;
  const lastRow = rows[rows.length - 1];
  const nextCursor = hasMore && lastRow ? encodeCustomerCursor(lastRow) : null;

  return {
    data: rows.map((customer) => formatCustomer(customer)),
    next_cursor: nextCursor,
  };
}

/**
 * docs/modules/customers/specification.md#4-api-contract — GET /api/v1/customers/{id}/purchase-history.
 */
export async function getPurchaseHistory(
  tenantId: string,
  customerId: string,
  query: { cursor?: string; limit: number },
) {
  const existing = await repository.findCustomerById(tenantId, customerId);
  if (!existing) {
    throw new ApiError(404, "NOT_FOUND", `Customer ${customerId} not found.`);
  }

  const decodedCursor = query.cursor ? decodePurchaseHistoryCursor(query.cursor) : null;
  const fetched = await repository.listPurchaseHistory(
    tenantId,
    customerId,
    decodedCursor,
    query.limit,
  );
  const hasMore = fetched.length > query.limit;
  const rows = hasMore ? fetched.slice(0, query.limit) : fetched;
  const lastRow = rows[rows.length - 1];
  const nextCursor = hasMore && lastRow ? encodePurchaseHistoryCursor(lastRow) : null;

  return {
    data: rows.map((sale) => ({
      id: sale.id,
      provisional_invoice_number: sale.provisionalInvoiceNumber,
      grand_total_minor_units: Number(sale.grandTotalMinorUnits),
      completed_at: sale.completedAt.toISOString(),
    })),
    next_cursor: nextCursor,
  };
}

function encodeCustomerCursor(row: CustomerCursor): string {
  return Buffer.from(`${row.updatedAt.toISOString()}|${row.id}`).toString("base64url");
}

function decodeCustomerCursor(cursor: string): CustomerCursor {
  const [updatedAtIso, id] = decodeCursorParts(cursor);
  const updatedAt = new Date(updatedAtIso);
  if (Number.isNaN(updatedAt.getTime()) || !id) {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }
  return { updatedAt, id };
}

function encodePurchaseHistoryCursor(row: PurchaseHistoryCursor): string {
  return Buffer.from(`${row.completedAt.toISOString()}|${row.id}`).toString("base64url");
}

function decodePurchaseHistoryCursor(cursor: string): PurchaseHistoryCursor {
  const [completedAtIso, id] = decodeCursorParts(cursor);
  const completedAt = new Date(completedAtIso);
  if (Number.isNaN(completedAt.getTime()) || !id) {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }
  return { completedAt, id };
}

function decodeCursorParts(cursor: string): [string, string] {
  try {
    const [a, b] = Buffer.from(cursor, "base64url").toString("utf8").split("|");
    if (!a || !b) throw new Error("malformed");
    return [a, b];
  } catch {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }
}
