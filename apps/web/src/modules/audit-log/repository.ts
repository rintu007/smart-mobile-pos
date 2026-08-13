import { prisma } from "@/core/db/client";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

export interface AuditLogCursor {
  createdAt: Date;
  id: string;
}

export interface ListAuditLogFilters {
  entityType?: string;
  entityId?: string;
  dateFrom?: Date;
  dateTo?: Date;
}

// (created_at, id) cursor — Tier 2, no updated_at column on this table (schema-server.md), same
// shape stock_movements' own history list already established. date_from/date_to and the cursor
// both key off createdAt but as sibling top-level conditions, not two colliding OR keys.
export function listAuditLog(
  tenantId: string,
  filters: ListAuditLogFilters,
  cursor: AuditLogCursor | null,
  limit: number,
) {
  return prisma.auditLog.findMany({
    where: {
      tenantId,
      ...(filters.entityType ? { entityType: filters.entityType } : {}),
      ...(filters.entityId ? { entityId: filters.entityId } : {}),
      ...(filters.dateFrom || filters.dateTo
        ? {
            createdAt: {
              ...(filters.dateFrom ? { gte: filters.dateFrom } : {}),
              ...(filters.dateTo ? { lte: filters.dateTo } : {}),
            },
          }
        : {}),
      ...(cursor
        ? {
            OR: [
              { createdAt: { gt: cursor.createdAt } },
              { createdAt: cursor.createdAt, id: { gt: cursor.id } },
            ],
          }
        : {}),
    },
    orderBy: [{ createdAt: "asc" }, { id: "asc" }],
    take: limit + 1,
  });
}
