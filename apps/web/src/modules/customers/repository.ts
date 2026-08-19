import { randomUUID } from "node:crypto";
import { prisma } from "@/core/db/client";
import type { CreateCustomerRequest } from "./schema";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

export function findCustomerById(tenantId: string, id: string) {
  return prisma.customer.findFirst({ where: { id, tenantId } });
}

// Upsert-on-id, same idempotent-replay mechanism as products/repository.ts's createProduct —
// docs/11-api/api-principles.md §3.
export function createCustomer(
  input: CreateCustomerRequest & { tenantId: string; createdBy: string },
) {
  return prisma.customer.upsert({
    where: { id: input.id },
    create: {
      id: input.id,
      tenantId: input.tenantId,
      name: input.name,
      phone: input.phone,
      createdBy: input.createdBy,
    },
    update: {},
  });
}

// docs/modules/customers/specification.md §1c — writes only the fields the merge algorithm decided
// to apply (never a raw copy of the request body — a field left out of `applied` must not be
// touched, whether because this edit didn't intend to change it or because it's in conflict).
// `updatedBy` feeds the *next* conflict's own attribution (§1c). A no-op (nothing applied) never
// reaches here — service.ts skips the call entirely, so `updated_at` never bumps for a request that
// changed nothing.
export function updateCustomerFields(
  id: string,
  applied: { name?: string | null; phone?: string | null },
  updatedBy: string,
) {
  return prisma.customer.update({ where: { id }, data: { ...applied, updatedBy } });
}

export interface FieldConflictInput {
  field: string;
  currentValue: string | null;
  currentSetBy: string;
  attemptedValue: string | null;
  attemptedSetBy: string;
}

// docs/modules/customers/specification.md §1c/§3 — one row per genuinely conflicting field in a
// single update call (a request can conflict on `name`, `phone`, both, or neither, independently).
export function createFieldConflicts(
  tenantId: string,
  customerId: string,
  conflicts: FieldConflictInput[],
) {
  return prisma.customerFieldConflict.createMany({
    data: conflicts.map((conflict) => ({
      id: randomUUID(),
      tenantId,
      customerId,
      field: conflict.field,
      currentValue: conflict.currentValue,
      currentSetBy: conflict.currentSetBy,
      attemptedValue: conflict.attemptedValue,
      attemptedSetBy: conflict.attemptedSetBy,
    })),
  });
}

export function findConflictById(tenantId: string, id: string) {
  return prisma.customerFieldConflict.findFirst({
    where: { id, tenantId },
    include: {
      customer: true,
      currentSetByUser: true,
      attemptedSetByUser: true,
    },
  });
}

export interface ConflictCursor {
  createdAt: Date;
  id: string;
}

// docs/modules/customers/specification.md §4 — GET /customers/conflicts. Unresolved only,
// most-recent-first (matching purchase-history's own "review list" ordering reasoning).
export function listUnresolvedConflicts(
  tenantId: string,
  cursor: ConflictCursor | null,
  limit: number,
) {
  return prisma.customerFieldConflict.findMany({
    where: {
      tenantId,
      resolvedAt: null,
      ...(cursor
        ? {
            OR: [
              { createdAt: { lt: cursor.createdAt } },
              { createdAt: cursor.createdAt, id: { lt: cursor.id } },
            ],
          }
        : {}),
    },
    include: { customer: true, currentSetByUser: true, attemptedSetByUser: true },
    orderBy: [{ createdAt: "desc" }, { id: "desc" }],
    take: limit + 1,
  });
}

export interface ResolveConflictInput {
  conflictId: string;
  customerId: string;
  resolvedValue: string | null;
  resolvedBy: string;
}

// docs/modules/customers/specification.md §1c — writes the chosen value to the customer row
// (bumping updated_at/updated_by normally) and marks the conflict resolved, atomically.
export function resolveConflict(input: ResolveConflictInput) {
  return prisma.$transaction(async (tx) => {
    const conflict = await tx.customerFieldConflict.update({
      where: { id: input.conflictId },
      data: {
        resolvedAt: new Date(),
        resolvedValue: input.resolvedValue,
        resolvedBy: input.resolvedBy,
      },
    });

    // Dynamic-key assignment doesn't type-check against Prisma's strict update input — `field` is
    // only ever 'name' | 'phone' (enforced when the conflict was created), so an explicit branch.
    const customer = await tx.customer.update({
      where: { id: input.customerId },
      data:
        conflict.field === "name"
          ? { name: input.resolvedValue, updatedBy: input.resolvedBy }
          : { phone: input.resolvedValue, updatedBy: input.resolvedBy },
    });

    return { conflict, customer };
  });
}

// docs/modules/customers/specification.md §2 — soft delete, idempotent (the caller checks
// deactivatedAt before calling this, same short-circuit deactivateUser's own service function
// already establishes for the structurally identical case).
export function deactivateCustomer(id: string) {
  return prisma.customer.update({ where: { id }, data: { deactivatedAt: new Date() } });
}

// Sprint 46 (docs/12-security/privacy.md §4) — anonymises rather than deletes: `name`/`phone`
// overwritten with `null`, the row's own `id` untouched, so every historical `sales.customer_id`
// FK stays valid. `deactivatedAtIfUnset` is the service layer's own decision (not this function's)
// about whether to also deactivate — passed as `null` when the customer is already deactivated, so
// a genuinely earlier deactivation timestamp is never overwritten by this call. Idempotent: the
// caller checks `erasedAt` before calling this, same short-circuit shape as `deactivateCustomer`
// above.
export function eraseCustomer(id: string, deactivatedAtIfUnset: Date | null) {
  return prisma.customer.update({
    where: { id },
    data: {
      name: null,
      phone: null,
      erasedAt: new Date(),
      ...(deactivatedAtIfUnset ? { deactivatedAt: deactivatedAtIfUnset } : {}),
    },
  });
}

export interface CustomerCursor {
  updatedAt: Date;
  id: string;
}

// docs/modules/customers/specification.md §2/§4 — GET /customers. Excludes deactivated customers
// by default (no query param to include them this sprint — a named, deliberate simplification).
// Cursor on (updated_at, id), matching products/repository.ts's own convention. Fetches limit + 1
// as a peek, the same off-by-one fix every other list endpoint in this codebase already applies.
export function listCustomers(
  tenantId: string,
  filters: { phone?: string },
  cursor: CustomerCursor | null,
  limit: number,
) {
  return prisma.customer.findMany({
    where: {
      tenantId,
      deactivatedAt: null,
      ...(filters.phone ? { phone: filters.phone } : {}),
      ...(cursor
        ? {
            OR: [
              { updatedAt: { gt: cursor.updatedAt } },
              { updatedAt: cursor.updatedAt, id: { gt: cursor.id } },
            ],
          }
        : {}),
    },
    orderBy: [{ updatedAt: "asc" }, { id: "asc" }],
    take: limit + 1,
  });
}

export interface PurchaseHistoryCursor {
  completedAt: Date;
  id: string;
}

// docs/modules/customers/specification.md §2/§4 — GET /customers/{id}/purchase-history.
// `status: 'completed'` only (§2 — a draft/held sale is never attributable to a customer's
// history). Ordered (completed_at, id) **desc**, per FR-051/customers.md, the mirror image of
// sales-invoices/repository.ts's own ascending listSales cursor: "next page" here means older, so
// the comparison direction flips to `lt`.
export function listPurchaseHistory(
  tenantId: string,
  customerId: string,
  cursor: PurchaseHistoryCursor | null,
  limit: number,
) {
  return prisma.sale.findMany({
    where: {
      tenantId,
      customerId,
      status: "completed",
      ...(cursor
        ? {
            OR: [
              { completedAt: { lt: cursor.completedAt } },
              { completedAt: cursor.completedAt, id: { lt: cursor.id } },
            ],
          }
        : {}),
    },
    orderBy: [{ completedAt: "desc" }, { id: "desc" }],
    take: limit + 1,
  });
}
