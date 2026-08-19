import * as productsService from "@/modules/products/service";
import * as posService from "@/modules/pos/service";
import * as customersService from "@/modules/customers/service";
import * as returnsService from "@/modules/returns/service";
import { createProductRequestSchema } from "@/modules/products/schema";
import { createSaleRequestSchema } from "@/modules/pos/schema";
import { createCustomerRequestSchema, syncUpdateCustomerPayloadSchema } from "@/modules/customers/schema";
import {
  createReturnRequestSchema,
  syncApproveReturnPayloadSchema,
  syncRejectReturnPayloadSchema,
} from "@/modules/returns/schema";
import * as stockMovementsRepository from "@/modules/stock-movements/repository";
import type { StockMovementCursor } from "@/modules/stock-movements/repository";
import * as settingsRepository from "@/modules/settings/repository";
import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import type { ProductCursor, SaleCursor } from "./repository";
import type { SyncPushOperation, SyncPushRequest } from "./schema";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

interface OperationResult {
  client_operation_id: string;
  status: "accepted" | "rejected";
  entity_id?: string;
  error?: { code: string; message: string };
}

// sync-api.md §2's full six-group ordering collapses to these groups this sprint (only these
// operation types have a client-facing write path at all — docs/modules/sync-engine/specification.md §1).
// `customer.create` (Sprint 32) is ordered alongside `product.create`, both before `sale.create` —
// a sale referencing a customer created in the same batch needs that customer to exist first.
// `return.create` (Sprint 33) is ordered after `sale.create` — a return references a sale that may
// have arrived in the same batch — and `return.approve`/`return.reject` after `return.create`, in
// case a same-batch approve/reject targets a return also created in that batch (unlikely in
// practice, but ordered correctly regardless — docs/modules/returns/specification.md §7).
// `customer.update` (Sprint 35) sits alongside `customer.create`, both in sync-api.md §2's
// `customer.*` group — before `sale.create`, matching that document's own fixed group order.
const TYPE_ORDER: SyncPushOperation["type"][] = [
  "product.create",
  "customer.create",
  "customer.update",
  "sale.create",
  "return.create",
  "return.approve",
  "return.reject",
];

/**
 * docs/modules/sync-engine/specification.md#4-api-contract.
 *
 * Dispatches each operation to the exact same service function its direct endpoint already calls
 * — no new idempotency mechanism is added (sync-api.md §5); `createProduct`/`createSale`'s
 * existing id-based idempotent-creation guarantee applies unchanged to a replayed batch.
 */
export async function pushOperations(
  authUserId: string,
  tenantId: string,
  input: SyncPushRequest,
): Promise<{ results: OperationResult[] }> {
  const ordered = [...input.operations].sort(
    (a, b) => TYPE_ORDER.indexOf(a.type) - TYPE_ORDER.indexOf(b.type),
  );

  const resultsByOperationId = new Map<string, OperationResult>();
  for (const operation of ordered) {
    resultsByOperationId.set(
      operation.client_operation_id,
      await runOperation(authUserId, tenantId, operation),
    );
  }

  // sync-api.md §3: results mirror the request's own original order, not the processing order.
  return {
    results: input.operations.map(
      (operation) => resultsByOperationId.get(operation.client_operation_id)!,
    ),
  };
}

async function runOperation(
  authUserId: string,
  tenantId: string,
  operation: SyncPushOperation,
): Promise<OperationResult> {
  try {
    if (operation.type === "product.create") {
      const parsed = createProductRequestSchema.safeParse(operation.payload);
      if (!parsed.success) {
        return rejected(operation.client_operation_id, "VALIDATION_FAILED", "Product payload failed validation.");
      }
      const product = await productsService.createProduct(authUserId, tenantId, parsed.data);
      return { client_operation_id: operation.client_operation_id, status: "accepted", entity_id: product.id };
    }

    if (operation.type === "customer.create") {
      const parsed = createCustomerRequestSchema.safeParse(operation.payload);
      if (!parsed.success) {
        return rejected(operation.client_operation_id, "VALIDATION_FAILED", "Customer payload failed validation.");
      }
      const customer = await customersService.createCustomer(authUserId, tenantId, parsed.data);
      return { client_operation_id: operation.client_operation_id, status: "accepted", entity_id: customer.id };
    }

    if (operation.type === "customer.update") {
      const parsed = syncUpdateCustomerPayloadSchema.safeParse(operation.payload);
      if (!parsed.success) {
        return rejected(operation.client_operation_id, "VALIDATION_FAILED", "Customer update payload failed validation.");
      }
      const { id, ...updateInput } = parsed.data;
      const customer = await customersService.updateCustomer(authUserId, tenantId, id, updateInput);
      return { client_operation_id: operation.client_operation_id, status: "accepted", entity_id: customer.id };
    }

    if (operation.type === "sale.create") {
      const parsed = createSaleRequestSchema.safeParse(operation.payload);
      if (!parsed.success) {
        return rejected(operation.client_operation_id, "VALIDATION_FAILED", "Sale payload failed validation.");
      }
      const sale = await posService.createSale(authUserId, tenantId, parsed.data);
      return { client_operation_id: operation.client_operation_id, status: "accepted", entity_id: sale.id };
    }

    if (operation.type === "return.create") {
      const parsed = createReturnRequestSchema.safeParse(operation.payload);
      if (!parsed.success) {
        return rejected(operation.client_operation_id, "VALIDATION_FAILED", "Return payload failed validation.");
      }
      const returnRecord = await returnsService.createReturn(authUserId, tenantId, parsed.data);
      return { client_operation_id: operation.client_operation_id, status: "accepted", entity_id: returnRecord.id };
    }

    if (operation.type === "return.approve") {
      const parsed = syncApproveReturnPayloadSchema.safeParse(operation.payload);
      if (!parsed.success) {
        return rejected(operation.client_operation_id, "VALIDATION_FAILED", "Return approve payload failed validation.");
      }
      const returnRecord = await returnsService.approveReturn(authUserId, tenantId, parsed.data.id);
      return { client_operation_id: operation.client_operation_id, status: "accepted", entity_id: returnRecord.id };
    }

    // operation.type === "return.reject" — the schema's own enum guarantees no other value reaches here.
    const parsed = syncRejectReturnPayloadSchema.safeParse(operation.payload);
    if (!parsed.success) {
      return rejected(operation.client_operation_id, "VALIDATION_FAILED", "Return reject payload failed validation.");
    }
    const returnRecord = await returnsService.rejectReturn(
      authUserId,
      tenantId,
      parsed.data.id,
      parsed.data.reason,
    );
    return { client_operation_id: operation.client_operation_id, status: "accepted", entity_id: returnRecord.id };
  } catch (error) {
    if (error instanceof ApiError) {
      // sync-api.md §4: a sale referencing a product not yet synced from another device, or a
      // return referencing a sale not yet synced, is a retryable "not synced yet", not a permanent
      // NOT_FOUND/ORIGINAL_SALE_NOT_FOUND — remapped only in this context (returns.md's own
      // documented ORIGINAL_SALE_NOT_FOUND note, docs/modules/returns/specification.md §6).
      const code =
        (operation.type === "sale.create" && error.code === "NOT_FOUND") ||
        (operation.type === "return.create" && error.code === "ORIGINAL_SALE_NOT_FOUND")
          ? "DEPENDENCY_NOT_FOUND"
          : error.code;
      return rejected(operation.client_operation_id, code, error.message);
    }
    throw error;
  }
}

function rejected(clientOperationId: string, code: string, message: string): OperationResult {
  return { client_operation_id: clientOperationId, status: "rejected", error: { code, message } };
}

/**
 * docs/modules/sync-engine/specification.md#4-api-contract — GET /sync/pull, entity_type=products.
 */
export async function pullProducts(tenantId: string, cursor: string | undefined, limit: number) {
  const decodedCursor = cursor ? decodeCursor(cursor) : null;
  const fetched = await repository.listProductsForSync(tenantId, decodedCursor, limit);
  // repository fetches limit + 1 as a peek — trim it off before returning; its mere presence is
  // what tells us a next page exists, distinct from a page that just happens to exactly fill.
  const hasMore = fetched.length > limit;
  const rows = hasMore ? fetched.slice(0, limit) : fetched;
  const lastRow = rows[rows.length - 1];
  const nextCursor = hasMore && lastRow ? encodeCursor(lastRow) : null;

  return {
    // category_id/unit_id/sku/barcode added Sprint 21 (backlog.md item 5) — a real gap found
    // while extending this exact mapping for the mobile barcode-scan feature: Sprint 20 added
    // these columns to the server table and the local Products table, but this pull response
    // never carried them down, so only a device's own locally-created products ever had them —
    // a product created on another device, or directly against the server, pulled down with both
    // fields null regardless of what the server actually held. Fixed in the same pass, not left
    // for a later sprint to rediscover.
    data: rows.map((product) => ({
      id: product.id,
      name: product.name,
      price_minor_units: Number(product.priceMinorUnits),
      category_id: product.categoryId,
      unit_id: product.unitId,
      sku: product.sku,
      barcode: product.barcode,
      created_at: product.createdAt.toISOString(),
      updated_at: product.updatedAt.toISOString(),
    })),
    next_cursor: nextCursor,
  };
}

function encodeCursor(row: ProductCursor): string {
  return Buffer.from(`${row.updatedAt.toISOString()}|${row.id}`).toString("base64url");
}

function decodeCursor(cursor: string): ProductCursor {
  let updatedAtIso: string | undefined;
  let id: string | undefined;
  try {
    [updatedAtIso, id] = Buffer.from(cursor, "base64url").toString("utf8").split("|");
  } catch {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }

  const updatedAt = updatedAtIso ? new Date(updatedAtIso) : undefined;
  if (!updatedAt || Number.isNaN(updatedAt.getTime()) || !id) {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }

  return { updatedAt, id };
}

/**
 * docs/13-offline-sync/inbound-sync.md §4 — "a rolling window covering the current and prior
 * financial year," decided there but never actually implemented until Sprint 53 (the pull below
 * called `listStockMovements` with no `dateFrom` at all — found while building storage-full
 * handling, tracing back why the local cache had no bound). Mirrors pos/repository.ts's own
 * `financialYearFor` exactly (April 1 rollover, UTC) rather than importing it — that function is
 * module-private there, and this is the only other call site so far.
 */
export function stockMovementsRetentionCutoff(now: Date): Date {
  const currentFyStartYear = now.getUTCMonth() >= 3 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
  return new Date(Date.UTC(currentFyStartYear - 1, 3, 1));
}

/**
 * docs/modules/sync-engine/specification.md#4-api-contract — GET /sync/pull, entity_type=stock_movements.
 * Added Sprint 36 (backlog.md M4 item 1). Reuses stock-movements/repository.ts's own
 * `listStockMovements` — the same tenant-scoped, `(created_at, id)`-cursor, `limit + 1`
 * peek query GET /stock-movements already relies on, no dedicated sync-only query needed here
 * (unlike sales, below, which does need one for its line items). Bounded to the current + prior
 * financial year since Sprint 53 — see `stockMovementsRetentionCutoff` above. `now` is an optional
 * trailing param (defaults to the real clock) purely for test injection, the same shape every
 * other optional-trailing-param precedent in this codebase already uses — not a design choice a
 * real caller needs to think about.
 */
export async function pullStockMovements(
  tenantId: string,
  cursor: string | undefined,
  limit: number,
  now: Date = new Date(),
) {
  const decodedCursor = cursor ? decodeStockMovementCursor(cursor) : null;
  const fetched = await stockMovementsRepository.listStockMovements(
    tenantId,
    { dateFrom: stockMovementsRetentionCutoff(now) },
    decodedCursor,
    limit,
  );
  const hasMore = fetched.length > limit;
  const rows = hasMore ? fetched.slice(0, limit) : fetched;
  const lastRow = rows[rows.length - 1];

  return {
    data: rows.map((movement) => ({
      id: movement.id,
      product_id: movement.productId,
      store_id: movement.storeId,
      quantity_delta: movement.quantityDelta,
      movement_type: movement.movementType,
      reason_code: movement.reasonCode,
      reference_type: movement.referenceType,
      reference_id: movement.referenceId,
      created_at: movement.createdAt.toISOString(),
    })),
    // Unlike pullProducts' next_cursor (null once the last page is reached — a "keep paging within
    // this run?" signal only), this entity type's next_cursor is always the last row actually seen,
    // so the mobile client can persist it as the next sync cycle's own resume point — a real
    // efficiency need `pullProducts` never had (a small, near-static catalogue vs. an
    // ever-growing transaction history, docs/modules/sync-engine/specification.md §2). `has_more`
    // carries the "keep paging right now" signal instead. An empty page (no new rows since the
    // caller's own cursor) echoes that cursor back unchanged, never null, so a quiet sync never
    // resets an established resume point back to the beginning.
    next_cursor: lastRow ? encodeStockMovementCursor(lastRow) : (cursor ?? null),
    has_more: hasMore,
  };
}

function encodeStockMovementCursor(row: StockMovementCursor): string {
  return Buffer.from(`${row.createdAt.toISOString()}|${row.id}`).toString("base64url");
}

function decodeStockMovementCursor(cursor: string): StockMovementCursor {
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

/**
 * docs/modules/sync-engine/specification.md#4-api-contract — GET /sync/pull, entity_type=sales.
 * Added Sprint 36 (backlog.md M4 item 1). Reuses `posService.formatSale` — the exact same shape
 * `GET /sales/{id}` already returns — plus `created_at`, which that endpoint's own contract never
 * needed to expose but this pull does (schema-local.md's local `Sales.createdAt` column, used to
 * order/scope Reports queries by date range, FR-073).
 */
export async function pullSales(tenantId: string, cursor: string | undefined, limit: number) {
  const decodedCursor = cursor ? decodeSaleCursor(cursor) : null;
  const fetched = await repository.listSalesForSync(tenantId, decodedCursor, limit);
  const hasMore = fetched.length > limit;
  const rows = hasMore ? fetched.slice(0, limit) : fetched;
  const lastRow = rows[rows.length - 1];

  return {
    data: rows.map((sale) => ({ ...posService.formatSale(sale), created_at: sale.createdAt.toISOString() })),
    // Same always-the-last-row-seen / has_more split as pullStockMovements above, same reasoning.
    next_cursor: lastRow ? encodeSaleCursor(lastRow) : (cursor ?? null),
    has_more: hasMore,
  };
}

function encodeSaleCursor(row: SaleCursor): string {
  return Buffer.from(`${row.completedAt.toISOString()}|${row.id}`).toString("base64url");
}

function decodeSaleCursor(cursor: string): SaleCursor {
  let completedAtIso: string | undefined;
  let id: string | undefined;
  try {
    [completedAtIso, id] = Buffer.from(cursor, "base64url").toString("utf8").split("|");
  } catch {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }

  const completedAt = completedAtIso ? new Date(completedAtIso) : undefined;
  if (!completedAt || Number.isNaN(completedAt.getTime()) || !id) {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }

  return { completedAt, id };
}

/**
 * docs/modules/sync-engine/specification.md#4-api-contract — GET /sync/pull, entity_type=shop_settings.
 * Added Sprint 37 (backlog.md M4 item 2), extended Sprint 39 (M4 item 4) with
 * `receipt_footer_message`. Unlike every other pull entity type, `shop_settings` is exactly one row
 * per tenant — no cursor pagination is meaningful, `cursor`/`limit` are accepted (schema-level) but
 * unused. Deliberately minimal: only the fields an offline feature actually needs (Reports' low-stock
 * threshold, `ReceiptFormatter`'s footer message per FR-077/FR-078's "Fully offline" classification)
 * — not the full `GET /settings` shape, which stays role-shaped and full-featured for its own direct
 * callers.
 */
export async function pullShopSettings(tenantId: string) {
  const settings = await settingsRepository.findSettings(tenantId);
  const receiptTemplateConfig = settings?.receiptTemplateConfig as { footer_message?: string } | null;

  return {
    data: settings
      ? [
          {
            low_stock_threshold_quantity: settings.lowStockThresholdQuantity,
            receipt_footer_message: receiptTemplateConfig?.footer_message ?? null,
          },
        ]
      : [],
    next_cursor: null,
    has_more: false,
  };
}
