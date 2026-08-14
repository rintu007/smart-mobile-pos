import { prisma } from "@/core/db/client";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.
// Independently queries the `sales` table via Prisma rather than importing pos/repository.ts
// directly — the same "each module owns its own read shape" pattern sync/repository.ts already
// established for its own independent read of `products`.

// docs/modules/sales-invoices/specification.md §4 — GET /sales/{id}. Tenant-scoped so a
// cross-tenant id resolves to NOT_FOUND, never a distinguishable "exists but not yours".
export function findSaleWithDetails(tenantId: string, id: string) {
  return prisma.sale.findFirst({
    where: { id, tenantId },
    include: { lineItems: true, payments: true },
  });
}

export interface InvoiceNumberFilter {
  provisionalInvoiceNumber?: string;
  canonicalInvoiceNumber?: bigint;
}

// docs/modules/sales-invoices/specification.md §4 — GET /sales/lookup. Exactly one filter is ever
// populated (schema.ts's own Zod refine guarantees this before this function is ever called).
export function findSaleByInvoiceNumber(tenantId: string, filter: InvoiceNumberFilter) {
  return prisma.sale.findFirst({
    where: {
      tenantId,
      ...(filter.provisionalInvoiceNumber
        ? { provisionalInvoiceNumber: filter.provisionalInvoiceNumber }
        : {}),
      ...(filter.canonicalInvoiceNumber !== undefined
        ? { canonicalInvoiceNumber: filter.canonicalInvoiceNumber }
        : {}),
    },
    include: { lineItems: true, payments: true },
  });
}

export interface SaleCursor {
  completedAt: Date;
  id: string;
}

export interface ListSalesFilters {
  createdBy?: string;
  dateFrom?: Date;
  dateTo?: Date;
}

// docs/modules/sales-invoices/specification.md §2/§4 — GET /sales. `createdBy` implements the
// Cashier-sees-own-sales-only scoping (resolved by the service layer from the caller's role, never
// this function's own concern); Manager/Owner pass no `createdBy` filter (store-wide). Cursor on
// (completed_at, id) — Tier 1 (sales already has updated-at-shaped semantics via completed_at),
// matching the index added this sprint. Fetches limit + 1 as a peek, same off-by-one fix every
// other list endpoint in this codebase already applies.
export function listSales(
  tenantId: string,
  filters: ListSalesFilters,
  cursor: SaleCursor | null,
  limit: number,
) {
  return prisma.sale.findMany({
    where: {
      tenantId,
      ...(filters.createdBy ? { createdBy: filters.createdBy } : {}),
      ...(filters.dateFrom || filters.dateTo
        ? {
            completedAt: {
              ...(filters.dateFrom ? { gte: filters.dateFrom } : {}),
              ...(filters.dateTo ? { lte: filters.dateTo } : {}),
            },
          }
        : {}),
      ...(cursor
        ? {
            OR: [
              { completedAt: { gt: cursor.completedAt } },
              { completedAt: cursor.completedAt, id: { gt: cursor.id } },
            ],
          }
        : {}),
    },
    orderBy: [{ completedAt: "asc" }, { id: "asc" }],
    take: limit + 1,
  });
}
