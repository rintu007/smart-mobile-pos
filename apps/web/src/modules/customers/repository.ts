import { prisma } from "@/core/db/client";
import type { CreateCustomerRequest, UpdateCustomerRequest } from "./schema";

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

// docs/modules/customers/specification.md §5 — PATCH. Plain update, no optimistic-concurrency
// check this sprint (§1: no concurrent-offline-edit caller exists yet to make one meaningful).
export function updateCustomer(id: string, data: UpdateCustomerRequest) {
  return prisma.customer.update({ where: { id }, data });
}

// docs/modules/customers/specification.md §2 — soft delete, idempotent (the caller checks
// deactivatedAt before calling this, same short-circuit deactivateUser's own service function
// already establishes for the structurally identical case).
export function deactivateCustomer(id: string) {
  return prisma.customer.update({ where: { id }, data: { deactivatedAt: new Date() } });
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
