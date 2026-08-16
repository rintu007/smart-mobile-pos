import * as productsService from "@/modules/products/service";
import * as posService from "@/modules/pos/service";
import * as customersService from "@/modules/customers/service";
import { createProductRequestSchema } from "@/modules/products/schema";
import { createSaleRequestSchema } from "@/modules/pos/schema";
import { createCustomerRequestSchema } from "@/modules/customers/schema";
import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import type { ProductCursor } from "./repository";
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
const TYPE_ORDER: SyncPushOperation["type"][] = ["product.create", "customer.create", "sale.create"];

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

    // operation.type === "sale.create" — the schema's own enum guarantees no other value reaches here.
    const parsed = createSaleRequestSchema.safeParse(operation.payload);
    if (!parsed.success) {
      return rejected(operation.client_operation_id, "VALIDATION_FAILED", "Sale payload failed validation.");
    }
    const sale = await posService.createSale(authUserId, tenantId, parsed.data);
    return { client_operation_id: operation.client_operation_id, status: "accepted", entity_id: sale.id };
  } catch (error) {
    if (error instanceof ApiError) {
      // sync-api.md §4: a sale referencing a product not yet synced from another device is a
      // retryable "not synced yet", not a permanent NOT_FOUND — remapped only in this context.
      const code =
        operation.type === "sale.create" && error.code === "NOT_FOUND"
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
