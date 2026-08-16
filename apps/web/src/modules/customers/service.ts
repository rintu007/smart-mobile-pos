import { Prisma } from "@prisma/client";
import * as identityService from "@/modules/identity/service";
import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import type { CustomerCursor, PurchaseHistoryCursor } from "./repository";
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

/**
 * docs/modules/customers/specification.md#4-api-contract — PATCH /api/v1/customers/{id}.
 * `undefined` fields are left unchanged; an explicit `null` clears the field — the merged result
 * is what CUSTOMER_IDENTIFIER_REQUIRED is checked against, not either value in isolation, since a
 * PATCH that clears the only identifier a customer has must be rejected the same way creation is.
 */
export async function updateCustomer(
  tenantId: string,
  id: string,
  input: UpdateCustomerRequest,
) {
  const existing = await repository.findCustomerById(tenantId, id);
  if (!existing) {
    throw new ApiError(404, "NOT_FOUND", `Customer ${id} not found.`);
  }

  const mergedName = input.name === undefined ? existing.name : input.name;
  const mergedPhone = input.phone === undefined ? existing.phone : input.phone;
  assertHasIdentifier(mergedName, mergedPhone);

  let customer;
  try {
    customer = await repository.updateCustomer(id, input);
  } catch (error) {
    translatePhoneConflict(error, input.phone);
  }

  return formatCustomer(customer);
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
