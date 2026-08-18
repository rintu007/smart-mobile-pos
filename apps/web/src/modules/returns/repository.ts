import { prisma } from "@/core/db/client";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.
// Reading the original sale/its line items is deliberately NOT done here — that goes through
// posService.getCompletedSaleForReturn (service-to-service, docs/modules/returns/specification.md §1).

export function findReturnById(tenantId: string, id: string) {
  return prisma.return.findFirst({ where: { id, tenantId }, include: { lineItems: true } });
}

// docs/modules/returns/specification.md §2 (DR-013) — the "quantity/refund already consumed
// against this line" check. Excludes `rejected` returns only: `pending_approval` still counts,
// matching schema-server.md's own index rationale ("SUM... across all non-rejected returns").
export function listNonRejectedReturnLineItems(tenantId: string, originalSaleLineItemIds: string[]) {
  return prisma.returnLineItem.findMany({
    where: {
      originalSaleLineItemId: { in: originalSaleLineItemIds },
      return: { tenantId, status: { not: "rejected" } },
    },
    select: { originalSaleLineItemId: true, quantity: true, refundAmountMinorUnits: true },
  });
}

export interface CreateReturnLineItemInput {
  id: string;
  originalSaleLineItemId: string;
  productId: string;
  quantity: number;
  refundAmountMinorUnits: bigint;
}

export interface CreateReturnInput {
  id: string;
  tenantId: string;
  storeId: string;
  originalSaleId: string;
  status: "completed" | "pending_approval";
  refundTotalMinorUnits: bigint;
  createdBy: string;
  lineItems: CreateReturnLineItemInput[];
}

// docs/modules/returns/specification.md §3 — `id` alone is this table's idempotency key (no
// separate `client_operation_id` column, a named deviation from schema-server.md's literal column
// list, §1 correction 2). Each stock movement reuses its own line item's `id`, the same 1:1
// idempotency-key-reuse `pos/repository.ts`'s own `createSale` already established. No stock
// movement/audit log is written for a `pending_approval` return — WF-012 step 5 (positive stock
// movement) only happens once the return actually completes, whether immediately (auto-approve) or
// later (approveReturn below).
export function createReturn(input: CreateReturnInput) {
  const completedAt = input.status === "completed" ? new Date() : null;

  return prisma.$transaction(async (tx) => {
    const created = await tx.return.create({
      data: {
        id: input.id,
        tenantId: input.tenantId,
        storeId: input.storeId,
        originalSaleId: input.originalSaleId,
        status: input.status,
        refundTotalMinorUnits: input.refundTotalMinorUnits,
        completedAt,
        createdBy: input.createdBy,
        lineItems: {
          create: input.lineItems.map((item) => ({
            id: item.id,
            originalSaleLineItemId: item.originalSaleLineItemId,
            quantity: item.quantity,
            refundAmountMinorUnits: item.refundAmountMinorUnits,
          })),
        },
      },
      include: { lineItems: true },
    });

    if (input.status === "completed") {
      // DR-004/FR-064: a positive stock movement per returned unit, in the same transaction.
      await tx.stockMovement.createMany({
        data: input.lineItems.map((item) => ({
          id: item.id,
          tenantId: input.tenantId,
          storeId: input.storeId,
          productId: item.productId,
          quantityDelta: item.quantity,
          movementType: "return",
          referenceType: "return",
          referenceId: input.id,
          createdBy: input.createdBy,
        })),
      });

      // DR-025 / audit-logging.md §1's Phase 14 correction (found unfixed Sprint 43, backlog.md M4
      // item 8): every stock_movements row gets its own paired audit_log entry — this is the
      // auto-approval path (an under-threshold return, `createReturn` itself sets `status:
      // "completed"` directly), a separate code path from `completeReturn` below, which needs the
      // exact same fix. Each entry reuses its own stock movement's id.
      await tx.auditLog.createMany({
        data: input.lineItems.map((item) => ({
          id: item.id,
          tenantId: input.tenantId,
          storeId: input.storeId,
          actorUserId: input.createdBy,
          action: "stock_movement.return",
          entityType: "stock_movement",
          entityId: item.id,
          afterState: {
            id: item.id,
            product_id: item.productId,
            quantity_delta: item.quantity,
            movement_type: "return",
            reference_type: "return",
            reference_id: input.id,
          },
        })),
      });

      // DR-025: one audit entry per completed return, in the same transaction. Reuses the return's
      // own id as this row's id, the same reuse pos/repository.ts's createSale already established.
      await tx.auditLog.create({
        data: {
          id: input.id,
          tenantId: input.tenantId,
          storeId: input.storeId,
          actorUserId: input.createdBy,
          action: "return.completed",
          entityType: "return",
          entityId: input.id,
          afterState: {
            id: input.id,
            status: "completed",
            refund_total_minor_units: Number(input.refundTotalMinorUnits),
            completed_at: completedAt?.toISOString() ?? null,
          },
        },
      });
    }

    return created;
  });
}

export interface CompleteReturnLineItemInput {
  id: string;
  productId: string;
  quantity: number;
}

export interface CompleteReturnInput {
  returnId: string;
  tenantId: string;
  storeId: string;
  approvedBy: string;
  refundTotalMinorUnits: bigint;
  lineItems: CompleteReturnLineItemInput[];
}

// docs/modules/returns/specification.md §2 (DR-017/018's actual mechanism lives in service.ts, not
// here — this function only ever runs once the caller's role has already been re-verified). Moves a
// `pending_approval` return to `completed`, writing the stock movements + audit entry WF-012 step 5
// requires, deferred until now for an above-threshold return.
export function completeReturn(input: CompleteReturnInput) {
  const completedAt = new Date();

  return prisma.$transaction(async (tx) => {
    const updated = await tx.return.update({
      where: { id: input.returnId },
      data: { status: "completed", approvedBy: input.approvedBy, completedAt },
      include: { lineItems: true },
    });

    await tx.stockMovement.createMany({
      data: input.lineItems.map((item) => ({
        id: item.id,
        tenantId: input.tenantId,
        storeId: input.storeId,
        productId: item.productId,
        quantityDelta: item.quantity,
        movementType: "return",
        referenceType: "return",
        referenceId: input.returnId,
        createdBy: input.approvedBy,
      })),
    });

    // DR-025 / audit-logging.md §1's Phase 14 correction (found unfixed Sprint 43, backlog.md M4
    // item 8): every stock_movements row gets its own paired audit_log entry — "return" movements
    // were the third of four movement types found still missing one, distinct from the single
    // "return.completed" entry below. Each entry reuses its own stock movement's id.
    await tx.auditLog.createMany({
      data: input.lineItems.map((item) => ({
        id: item.id,
        tenantId: input.tenantId,
        storeId: input.storeId,
        actorUserId: input.approvedBy,
        action: "stock_movement.return",
        entityType: "stock_movement",
        entityId: item.id,
        afterState: {
          id: item.id,
          product_id: item.productId,
          quantity_delta: item.quantity,
          movement_type: "return",
          reference_type: "return",
          reference_id: input.returnId,
        },
      })),
    });

    await tx.auditLog.create({
      data: {
        id: input.returnId,
        tenantId: input.tenantId,
        storeId: input.storeId,
        actorUserId: input.approvedBy,
        action: "return.completed",
        entityType: "return",
        entityId: input.returnId,
        afterState: {
          id: input.returnId,
          status: "completed",
          refund_total_minor_units: Number(input.refundTotalMinorUnits),
          completed_at: completedAt.toISOString(),
        },
      },
    });

    return updated;
  });
}

export interface RejectReturnInput {
  returnId: string;
  tenantId: string;
  storeId: string;
  actorUserId: string;
  reason: string;
}

// docs/modules/returns/specification.md §1 correction 4 — `reason` has no dedicated column
// (schema-server.md's returns table doesn't have one); it's captured in the audit entry's
// `after_state` instead.
export function rejectReturn(input: RejectReturnInput) {
  return prisma.$transaction(async (tx) => {
    const updated = await tx.return.update({
      where: { id: input.returnId },
      data: { status: "rejected" },
      include: { lineItems: true },
    });

    await tx.auditLog.create({
      data: {
        id: input.returnId,
        tenantId: input.tenantId,
        storeId: input.storeId,
        actorUserId: input.actorUserId,
        action: "return.rejected",
        entityType: "return",
        entityId: input.returnId,
        afterState: { id: input.returnId, status: "rejected", reason: input.reason },
      },
    });

    return updated;
  });
}

export interface ReturnCursor {
  createdAt: Date;
  id: string;
}

// docs/modules/returns/specification.md §4 — GET /returns / GET /returns/approvals. Descending on
// (created_at, id) — most-recent-first, matching customers/repository.ts's own purchase-history
// ordering reasoning for a review-style list.
export function listReturns(
  tenantId: string,
  filters: { createdBy?: string; status?: string },
  cursor: ReturnCursor | null,
  limit: number,
) {
  return prisma.return.findMany({
    where: {
      tenantId,
      ...(filters.createdBy ? { createdBy: filters.createdBy } : {}),
      ...(filters.status ? { status: filters.status } : {}),
      ...(cursor
        ? {
            OR: [
              { createdAt: { lt: cursor.createdAt } },
              { createdAt: cursor.createdAt, id: { lt: cursor.id } },
            ],
          }
        : {}),
    },
    orderBy: [{ createdAt: "desc" }, { id: "desc" }],
    take: limit + 1,
  });
}
