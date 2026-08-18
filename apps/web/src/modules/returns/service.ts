import { randomUUID } from "node:crypto";
import { Prisma } from "@prisma/client";
import * as identityService from "@/modules/identity/service";
import * as storesService from "@/modules/stores/service";
import * as rolesService from "@/modules/roles/service";
import * as settingsService from "@/modules/settings/service";
import * as posService from "@/modules/pos/service";
import { roundFraction } from "@/modules/pos/service";
import type { Role } from "@/modules/roles/schema";
import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import type { ReturnCursor } from "./repository";
import type { CreateReturnRequest } from "./schema";

const UNIQUE_CONSTRAINT_VIOLATION = "P2002";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

function formatReturn(ret: {
  id: string;
  originalSaleId: string;
  status: string;
  refundTotalMinorUnits: bigint;
  approvedBy: string | null;
  completedAt: Date | null;
  createdAt: Date;
  lineItems: {
    originalSaleLineItemId: string;
    quantity: number;
    refundAmountMinorUnits: bigint;
  }[];
}) {
  return {
    id: ret.id,
    original_sale_id: ret.originalSaleId,
    status: ret.status,
    refund_total_minor_units: Number(ret.refundTotalMinorUnits),
    approved_by: ret.approvedBy,
    line_items: ret.lineItems.map((item) => ({
      original_sale_line_item_id: item.originalSaleLineItemId,
      quantity: item.quantity,
      refund_amount_minor_units: Number(item.refundAmountMinorUnits),
    })),
    completed_at: ret.completedAt?.toISOString() ?? null,
    created_at: ret.createdAt.toISOString(),
  };
}

function formatReturnSummary(ret: {
  id: string;
  originalSaleId: string;
  status: string;
  refundTotalMinorUnits: bigint;
  approvedBy: string | null;
  completedAt: Date | null;
  createdAt: Date;
}) {
  return {
    id: ret.id,
    original_sale_id: ret.originalSaleId,
    status: ret.status,
    refund_total_minor_units: Number(ret.refundTotalMinorUnits),
    approved_by: ret.approvedBy,
    completed_at: ret.completedAt?.toISOString() ?? null,
    created_at: ret.createdAt.toISOString(),
  };
}

/**
 * docs/modules/returns/specification.md#4-api-contract — POST /api/v1/returns.
 *
 * Idempotent replay checked before any recompute, the same `findSaleById`-style short-circuit
 * `pos/service.ts`'s own `createSale` already established. Refund amounts are always
 * server-computed (DR-014, api-principles.md §7) — the client never supplies one.
 */
export async function createReturn(
  authUserId: string,
  tenantId: string,
  input: CreateReturnRequest,
) {
  const existing = await repository.findReturnById(tenantId, input.id);
  if (existing) {
    return formatReturn(existing);
  }

  const sale = await posService.getCompletedSaleForReturn(tenantId, input.original_sale_id);
  if (!sale) {
    throw new ApiError(
      404,
      "ORIGINAL_SALE_NOT_FOUND",
      `No completed sale ${input.original_sale_id} found under this tenant.`,
    );
  }

  const saleLineItemById = new Map(sale.lineItems.map((item) => [item.id, item]));
  for (const item of input.line_items) {
    if (!saleLineItemById.has(item.original_sale_line_item_id)) {
      throw new ApiError(
        404,
        "NOT_FOUND",
        `Line item ${item.original_sale_line_item_id} is not part of sale ${input.original_sale_id}.`,
      );
    }
  }

  // DR-013 — quantity/refund already consumed against each referenced line, across every
  // non-rejected return (specification.md §2).
  const alreadyReturned = await repository.listNonRejectedReturnLineItems(
    tenantId,
    input.line_items.map((item) => item.original_sale_line_item_id),
  );
  const consumedByLineItemId = new Map<string, { quantity: number; refundMinorUnits: bigint }>();
  for (const row of alreadyReturned) {
    const current = consumedByLineItemId.get(row.originalSaleLineItemId) ?? {
      quantity: 0,
      refundMinorUnits: BigInt(0),
    };
    consumedByLineItemId.set(row.originalSaleLineItemId, {
      quantity: current.quantity + row.quantity,
      refundMinorUnits: current.refundMinorUnits + row.refundAmountMinorUnits,
    });
  }

  const { roundingRule, returnAutoApprovalThresholdMinorUnits } =
    await settingsService.getMoneySettings(tenantId);

  const lineItems = input.line_items.map((item) => {
    const saleLineItem = saleLineItemById.get(item.original_sale_line_item_id)!;
    const consumed = consumedByLineItemId.get(item.original_sale_line_item_id) ?? {
      quantity: 0,
      refundMinorUnits: BigInt(0),
    };
    const remainingQuantity = saleLineItem.quantity - consumed.quantity;
    if (item.quantity > remainingQuantity) {
      throw new ApiError(
        409,
        "RETURN_QUANTITY_EXCEEDS_SOLD",
        `Line item ${item.original_sale_line_item_id} has only ${remainingQuantity} unit(s) left to return.`,
        {
          original_sale_line_item_id: item.original_sale_line_item_id,
          remaining_quantity: remainingQuantity,
        },
      );
    }

    // DR-014 rounding decision (specification.md §2): a full-remaining-quantity return refunds the
    // exact remaining amount (no division, no drift); a genuine partial uses proportional rounding.
    const remainingRefundMinorUnits = saleLineItem.lineTotalMinorUnits - consumed.refundMinorUnits;
    const refundAmountMinorUnits =
      item.quantity === remainingQuantity
        ? remainingRefundMinorUnits
        : roundFraction(
            saleLineItem.lineTotalMinorUnits * BigInt(item.quantity),
            BigInt(saleLineItem.quantity),
            roundingRule,
          );

    return {
      id: randomUUID(),
      originalSaleLineItemId: item.original_sale_line_item_id,
      productId: saleLineItem.productId,
      quantity: item.quantity,
      refundAmountMinorUnits,
    };
  });

  const refundTotalMinorUnits = lineItems.reduce(
    (sum, item) => sum + item.refundAmountMinorUnits,
    BigInt(0),
  );
  // DR-015 — not an error either way, a normal 201 with the resulting status (specification.md §2).
  const status =
    refundTotalMinorUnits > returnAutoApprovalThresholdMinorUnits ? "pending_approval" : "completed";

  const createdBy = await identityService.resolveUserId(authUserId);

  let created;
  try {
    created = await repository.createReturn({
      id: input.id,
      tenantId,
      storeId: sale.storeId,
      originalSaleId: input.original_sale_id,
      status,
      refundTotalMinorUnits,
      createdBy,
      lineItems,
    });
  } catch (error) {
    // Sprint 41 (backlog.md M4 item 6) — the same read-then-write replay race as
    // `pos/service.ts`'s `createSale` (found by the same new concurrent-composition suite),
    // same shape, same fix: this function's own top-of-function `findReturnById` check races
    // against a second genuinely concurrent push of the identical `id`.
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === UNIQUE_CONSTRAINT_VIOLATION) {
      const existingAfterRace = await repository.findReturnById(tenantId, input.id);
      if (existingAfterRace) {
        return formatReturn(existingAfterRace);
      }
    }
    throw error;
  }

  return formatReturn(created);
}

/**
 * docs/modules/returns/specification.md#4-api-contract — GET /api/v1/returns/{id}.
 */
export async function getReturnDetail(tenantId: string, id: string) {
  const ret = await repository.findReturnById(tenantId, id);
  if (!ret) {
    throw new ApiError(404, "NOT_FOUND", `Return ${id} not found.`);
  }
  return formatReturn(ret);
}

/**
 * docs/modules/returns/specification.md §2 (DR-017/018) — resolves the acting user's role fresh
 * from `user_store_roles`, independent of whichever Route Handler (or sync-push dispatch) reached
 * this function, and independent of whatever role that caller's own permission gate already
 * checked. Necessary for the sync-push path specifically: `POST /sync/push`'s own gate is generic
 * (cashier/manager/owner, since one batch can carry any operation type), so a `return.approve`/
 * `return.reject` operation is not otherwise role-checked at all before reaching here.
 */
async function assertActingManagerOrOwner(authUserId: string, tenantId: string): Promise<string> {
  const actorUserId = await identityService.resolveUserId(authUserId);
  const storeId = await storesService.getPrimaryStoreId(tenantId);
  const role = await rolesService.resolveActiveRole(tenantId, actorUserId, storeId);
  if (role !== "manager" && role !== "owner") {
    throw new ApiError(403, "PERMISSION_DENIED", "Only a Manager or Owner can decide a return.");
  }
  return actorUserId;
}

/**
 * docs/modules/returns/specification.md#4-api-contract — POST /api/v1/returns/{id}/approve.
 * Idempotent no-op if already `completed`; `RETURN_ALREADY_DECIDED` for any other non-
 * `pending_approval` state (i.e. `rejected`).
 */
export async function approveReturn(authUserId: string, tenantId: string, id: string) {
  const existing = await repository.findReturnById(tenantId, id);
  if (!existing) {
    throw new ApiError(404, "NOT_FOUND", `Return ${id} not found.`);
  }
  if (existing.status === "completed") {
    return formatReturn(existing);
  }
  if (existing.status !== "pending_approval") {
    throw new ApiError(409, "RETURN_ALREADY_DECIDED", "This return has already been decided.");
  }

  const actorUserId = await assertActingManagerOrOwner(authUserId, tenantId);

  const sale = await posService.getCompletedSaleForReturn(tenantId, existing.originalSaleId);
  if (!sale) {
    throw new ApiError(404, "ORIGINAL_SALE_NOT_FOUND", "The original sale is no longer resolvable.");
  }
  const productIdByLineItemId = new Map(sale.lineItems.map((item) => [item.id, item.productId]));

  let updated;
  try {
    updated = await repository.completeReturn({
      returnId: id,
      tenantId,
      storeId: existing.storeId,
      approvedBy: actorUserId,
      refundTotalMinorUnits: existing.refundTotalMinorUnits,
      lineItems: existing.lineItems.map((item) => ({
        id: item.id,
        productId: productIdByLineItemId.get(item.originalSaleLineItemId)!,
        quantity: item.quantity,
      })),
    });
  } catch (error) {
    // Sprint 41 (backlog.md M4 item 6) — the same class of race as `createSale`/`createReturn`
    // above, one step later in the lifecycle: two genuinely concurrent `approve` calls on the same
    // pending return can both pass the `status === "pending_approval"` check above before either
    // commits. `repository.completeReturn`'s own transaction reuses each return line item's id as
    // its stock-movement id (the same 1:1 idempotency-key reuse `products/repository.ts`'s opening
    // movement and `pos/repository.ts`'s sale movements already establish) — so the losing call's
    // `stockMovement.createMany` hits a real unique violation, rolling back that entire transaction
    // (including its own otherwise-harmless re-`update` of `returns.status`) and leaving the row
    // exactly as the winning call left it. Re-fetching and returning that is the correct idempotent
    // outcome, not an error.
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === UNIQUE_CONSTRAINT_VIOLATION) {
      const existingAfterRace = await repository.findReturnById(tenantId, id);
      if (existingAfterRace && existingAfterRace.status === "completed") {
        return formatReturn(existingAfterRace);
      }
    }
    throw error;
  }

  return formatReturn(updated);
}

/**
 * docs/modules/returns/specification.md#4-api-contract — POST /api/v1/returns/{id}/reject.
 * Idempotent no-op if already `rejected`; `RETURN_ALREADY_DECIDED` for any other non-
 * `pending_approval` state (i.e. `completed`).
 */
export async function rejectReturn(
  authUserId: string,
  tenantId: string,
  id: string,
  reason: string,
) {
  const existing = await repository.findReturnById(tenantId, id);
  if (!existing) {
    throw new ApiError(404, "NOT_FOUND", `Return ${id} not found.`);
  }
  if (existing.status === "rejected") {
    return formatReturn(existing);
  }
  if (existing.status !== "pending_approval") {
    throw new ApiError(409, "RETURN_ALREADY_DECIDED", "This return has already been decided.");
  }

  const actorUserId = await assertActingManagerOrOwner(authUserId, tenantId);

  const updated = await repository.rejectReturn({
    returnId: id,
    tenantId,
    storeId: existing.storeId,
    actorUserId,
    reason,
  });

  return formatReturn(updated);
}

/**
 * docs/modules/returns/specification.md#4-api-contract — GET /api/v1/returns. Cashier scoped to
 * their own `created_by` (the `created_by`-as-device-substitute adaptation specification.md §1
 * names); Manager/Owner see every return, store-wide.
 */
export async function listReturns(
  tenantId: string,
  role: Role,
  userId: string,
  query: { cursor?: string; limit: number; status?: string },
) {
  const decodedCursor = query.cursor ? decodeCursor(query.cursor) : null;
  const fetched = await repository.listReturns(
    tenantId,
    { createdBy: role === "cashier" ? userId : undefined, status: query.status },
    decodedCursor,
    query.limit,
  );
  const hasMore = fetched.length > query.limit;
  const rows = hasMore ? fetched.slice(0, query.limit) : fetched;
  const lastRow = rows[rows.length - 1];
  const nextCursor = hasMore && lastRow ? encodeCursor(lastRow) : null;

  return {
    data: rows.map((ret) => formatReturnSummary(ret)),
    next_cursor: nextCursor,
  };
}

/**
 * docs/modules/returns/specification.md#4-api-contract — GET /api/v1/returns/approvals.
 * `status` is always forced to `pending_approval`, regardless of any caller-supplied filter — this
 * endpoint's entire purpose is the approval queue, per navigation-model.md.
 */
export async function listApprovals(
  tenantId: string,
  query: { cursor?: string; limit: number },
) {
  const decodedCursor = query.cursor ? decodeCursor(query.cursor) : null;
  const fetched = await repository.listReturns(
    tenantId,
    { status: "pending_approval" },
    decodedCursor,
    query.limit,
  );
  const hasMore = fetched.length > query.limit;
  const rows = hasMore ? fetched.slice(0, query.limit) : fetched;
  const lastRow = rows[rows.length - 1];
  const nextCursor = hasMore && lastRow ? encodeCursor(lastRow) : null;

  return {
    data: rows.map((ret) => formatReturnSummary(ret)),
    next_cursor: nextCursor,
  };
}

function encodeCursor(row: ReturnCursor): string {
  return Buffer.from(`${row.createdAt.toISOString()}|${row.id}`).toString("base64url");
}

function decodeCursor(cursor: string): ReturnCursor {
  let createdAtIso: string | undefined;
  let id: string | undefined;
  try {
    [createdAtIso, id] = Buffer.from(cursor, "base64url").toString("utf8").split("|");
  } catch {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }

  const createdAt = createdAtIso ? new Date(createdAtIso) : undefined;
  if (!createdAt || Number.isNaN(createdAt.getTime()) || !id) {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }

  return { createdAt, id };
}
