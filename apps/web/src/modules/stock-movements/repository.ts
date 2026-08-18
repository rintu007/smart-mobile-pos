import { prisma } from "@/core/db/client";
import type { CreateStockMovementRequest } from "./schema";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

// docs/modules/inventory/specification.md §5 — product_id must reference a row under the same
// tenant, the same tenant-scoped existence check products/repository.ts already uses for
// category_id/unit_id.
export function findProductById(tenantId: string, id: string) {
  return prisma.product.findFirst({ where: { id, tenantId } });
}

export function createStockMovement(
  input: CreateStockMovementRequest & { tenantId: string; storeId: string; createdBy: string },
) {
  // Upsert-on-id, same idempotent-replay mechanism as every other creation endpoint —
  // docs/11-api/api-principles.md §3. Wrapped in a transaction (was a bare upsert before Sprint 43,
  // backlog.md M4 item 8) so the movement and its paired audit entry are created atomically.
  return prisma.$transaction(async (tx) => {
    const movement = await tx.stockMovement.upsert({
      where: { id: input.id },
      create: {
        id: input.id,
        tenantId: input.tenantId,
        storeId: input.storeId,
        productId: input.product_id,
        quantityDelta: input.quantity_delta,
        movementType: input.movement_type,
        reasonCode: input.reason_code ?? null,
        createdBy: input.createdBy,
      },
      update: {},
    });

    // DR-025 / audit-logging.md §1's Phase 14 correction (found unfixed Sprint 43, backlog.md M4
    // item 8): every stock_movements row gets its own paired audit_log entry — "adjustment" was the
    // fourth and last movement type found still missing one (the *only* one this project's own
    // v0.1.0 draft ever intended to log, per audit-logging.md's own correction note — even that
    // narrower original intent had never actually been implemented in code).
    await tx.auditLog.upsert({
      where: { id: input.id },
      create: {
        id: input.id,
        tenantId: input.tenantId,
        storeId: input.storeId,
        actorUserId: input.createdBy,
        action: "stock_movement.adjustment",
        entityType: "stock_movement",
        entityId: input.id,
        afterState: {
          id: input.id,
          product_id: input.product_id,
          quantity_delta: input.quantity_delta,
          movement_type: input.movement_type,
          reason_code: input.reason_code ?? null,
        },
      },
      update: {},
    });

    return movement;
  });
}

export interface StockMovementCursor {
  createdAt: Date;
  id: string;
}

export interface ListStockMovementsFilters {
  productId?: string;
  movementType?: string;
  dateFrom?: Date;
  dateTo?: Date;
}

// (created_at, id) cursor — Tier 2, no updated_at column on this table (schema-server.md).
// Fetches limit + 1 as a peek, same off-by-one fix every other list endpoint in this codebase
// already applies. date_from/date_to and the cursor both key off createdAt but as sibling
// top-level conditions (createdAt range vs. an OR tuple-comparison), not two colliding OR keys —
// no collision, unlike the search/cursor OR case products/repository.ts had to guard against.
export function listStockMovements(
  tenantId: string,
  filters: ListStockMovementsFilters,
  cursor: StockMovementCursor | null,
  limit: number,
) {
  return prisma.stockMovement.findMany({
    where: {
      tenantId,
      ...(filters.productId ? { productId: filters.productId } : {}),
      ...(filters.movementType ? { movementType: filters.movementType } : {}),
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

// docs/11-api/endpoints/inventory.md — the derived balance is always a server-side SUM, never a
// client-side sum of a locally cached movement list.
export async function getStockBalance(tenantId: string, storeId: string, productId: string) {
  const result = await prisma.stockMovement.aggregate({
    where: { tenantId, storeId, productId },
    _sum: { quantityDelta: true },
  });
  return result._sum.quantityDelta ?? 0;
}
