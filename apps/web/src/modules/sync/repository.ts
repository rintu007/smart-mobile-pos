import { prisma } from "@/core/db/client";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.
// Push writes nothing directly (service.ts calls products/pos's own service functions instead) —
// this file only supports pull.

export interface ProductCursor {
  updatedAt: Date;
  id: string;
}

// (updated_at, id) tuple comparison, per api-principles.md §4's Tier 1 cursor convention — Prisma
// has no native tuple `>` operator, so this is expressed as the equivalent OR.
//
// Fetches `limit + 1` rows so the caller can tell "exactly `limit` rows, and that's everything"
// apart from "exactly `limit` rows, and more exist" — without this peek, a page that happens to
// land exactly on `limit` is indistinguishable from a genuinely full page, so `next_cursor` would
// be wrongly non-null on the last page (found live, Sprint 13's own demo script).
export function listProductsForSync(tenantId: string, cursor: ProductCursor | null, limit: number) {
  return prisma.product.findMany({
    where: {
      tenantId,
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

// Added Sprint 36 (backlog.md M4 item 1) — sync-api.md §6's "reporting parity" pull, `sales` half.
// (completed_at, id) cursor, matching sales-invoices/repository.ts's own `SaleCursor` precedent —
// every synced sale is `status: 'completed'` (a draft/held row is never synced, docs/modules/pos/
// specification.md), so completedAt is as reliable a monotonic key as createdAt would be here.
// A dedicated query rather than reusing sales-invoices/repository.ts's own `listSales`: that query
// deliberately excludes line items (its own GET /sales list is a summary), and this pull needs them
// for Reports' top-products ranking (M4 item 2) — matches pullProducts' own precedent of owning its
// dedicated repository query rather than the direct endpoint's.
export interface SaleCursor {
  completedAt: Date;
  id: string;
}

export function listSalesForSync(tenantId: string, cursor: SaleCursor | null, limit: number) {
  return prisma.sale.findMany({
    where: {
      tenantId,
      status: "completed",
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
    include: { lineItems: true, payments: true },
  });
}
