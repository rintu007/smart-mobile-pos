import * as identityService from "@/modules/identity/service";
import * as storesService from "@/modules/stores/service";
import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import type { StockMovementCursor } from "./repository";
import type { CreateStockMovementRequest } from "./schema";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

// docs/modules/inventory/specification.md §1 — 'sale'/'return' pass Zod but are never directly
// postable; they're only ever produced server-side as a side effect of their own endpoint
// (POST /sales; returns doesn't exist yet, M3).
const NOT_DIRECTLY_POSTABLE = new Set(["sale", "return"]);

function formatStockMovement(movement: {
  id: string;
  productId: string;
  storeId: string;
  quantityDelta: number;
  movementType: string;
  reasonCode: string | null;
  referenceType: string | null;
  referenceId: string | null;
  createdAt: Date;
}) {
  return {
    id: movement.id,
    product_id: movement.productId,
    store_id: movement.storeId,
    quantity_delta: movement.quantityDelta,
    movement_type: movement.movementType,
    reason_code: movement.reasonCode,
    reference_type: movement.referenceType,
    reference_id: movement.referenceId,
    created_at: movement.createdAt.toISOString(),
  };
}

/**
 * docs/modules/inventory/specification.md#4-api-contract — POST /api/v1/stock-movements
 * (Sprint 22, backlog.md item 6). The only creatable type reaching the repository is
 * 'adjustment' — see §1 for why 'opening' is excluded at the schema layer entirely rather than
 * rejected here alongside 'sale'/'return'.
 *
 * No permission check beyond a valid tenant-scoped session — Roles & Permissions doesn't exist yet
 * (§4 of the spec), the same named scope boundary every M1 module before it has used.
 */
export async function createStockMovement(
  authUserId: string,
  tenantId: string,
  input: CreateStockMovementRequest,
) {
  if (NOT_DIRECTLY_POSTABLE.has(input.movement_type)) {
    throw new ApiError(
      403,
      "DIRECT_SALE_MOVEMENT_FORBIDDEN",
      `movement_type '${input.movement_type}' cannot be posted directly; it is only ever created as a side effect of its own endpoint.`,
    );
  }

  // DR-007: only 'adjustment' reaches here (NOT_DIRECTLY_POSTABLE above already filtered
  // sale/return, and 'opening' never passes the Zod enum at all).
  if (!input.reason_code) {
    throw new ApiError(
      422,
      "ADJUSTMENT_REASON_REQUIRED",
      "An adjustment movement requires a reason_code.",
    );
  }

  const product = await repository.findProductById(tenantId, input.product_id);
  if (!product) {
    throw new ApiError(404, "NOT_FOUND", `Product ${input.product_id} not found.`);
  }

  const createdBy = await identityService.resolveUserId(authUserId);
  const storeId = await storesService.getPrimaryStoreId(tenantId);

  const movement = await repository.createStockMovement({
    ...input,
    tenantId,
    storeId,
    createdBy,
  });

  return formatStockMovement(movement);
}

/**
 * docs/modules/inventory/specification.md#4-api-contract — GET /api/v1/stock-movements.
 */
export async function listStockMovements(
  tenantId: string,
  query: {
    cursor?: string;
    limit: number;
    product_id?: string;
    movement_type?: string;
    date_from?: string;
    date_to?: string;
  },
) {
  const decodedCursor = query.cursor ? decodeCursor(query.cursor) : null;
  const fetched = await repository.listStockMovements(
    tenantId,
    {
      productId: query.product_id,
      movementType: query.movement_type,
      dateFrom: query.date_from ? new Date(query.date_from) : undefined,
      dateTo: query.date_to ? new Date(query.date_to) : undefined,
    },
    decodedCursor,
    query.limit,
  );
  // Peek-and-trim, same reasoning every other list endpoint in this codebase already established.
  const hasMore = fetched.length > query.limit;
  const rows = hasMore ? fetched.slice(0, query.limit) : fetched;
  const lastRow = rows[rows.length - 1];
  const nextCursor = hasMore && lastRow ? encodeCursor(lastRow) : null;

  return {
    data: rows.map((movement) => formatStockMovement(movement)),
    next_cursor: nextCursor,
  };
}

/**
 * docs/modules/inventory/specification.md#4-api-contract — GET /api/v1/products/{id}/stock-balance.
 * The balance is always a server-computed SUM, never a client-side sum of a locally cached
 * movement list (inventory.md's own stated reasoning).
 */
export async function getStockBalance(tenantId: string, productId: string) {
  const product = await repository.findProductById(tenantId, productId);
  if (!product) {
    throw new ApiError(404, "NOT_FOUND", `Product ${productId} not found.`);
  }

  const storeId = await storesService.getPrimaryStoreId(tenantId);
  const balance = await repository.getStockBalance(tenantId, storeId, productId);

  return { product_id: productId, store_id: storeId, balance };
}

function encodeCursor(row: StockMovementCursor): string {
  return Buffer.from(`${row.createdAt.toISOString()}|${row.id}`).toString("base64url");
}

function decodeCursor(cursor: string): StockMovementCursor {
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
