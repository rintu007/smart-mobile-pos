import * as identityService from "@/modules/identity/service";
import * as storesService from "@/modules/stores/service";
import * as repository from "./repository";
import type { CreateProductRequest } from "./schema";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

/**
 * docs/modules/products/specification.md#4-api-contract.
 *
 * No permission check beyond a valid tenant-scoped session — Roles & Permissions doesn't exist yet
 * (§2 of the spec), a named scope boundary, not an oversight.
 */
export async function createProduct(
  authUserId: string,
  tenantId: string,
  input: CreateProductRequest,
) {
  // service-to-service is the one sanctioned cross-module path (layering-rules.md §2) — resolves
  // the internal `users.id` this row's `created_by` needs from the session's Supabase auth id.
  const createdBy = await identityService.resolveUserId(authUserId);
  // Products aren't store-scoped themselves (§3), but the opening stock movement this creation
  // produces is (docs/modules/inventory/specification.md §1) — resolved server-side, never from
  // the request, same principle inventory.md's own endpoint states for stock-movement writes.
  const storeId = await storesService.getPrimaryStoreId(tenantId);

  const product = await repository.createProduct({ ...input, tenantId, createdBy, storeId });

  return {
    id: product.id,
    name: product.name,
    // BigInt has no native JSON representation — safe to convert to Number here since realistic
    // minor-unit prices are nowhere near Number.MAX_SAFE_INTEGER (2^53 - 1).
    price_minor_units: Number(product.priceMinorUnits),
    created_at: product.createdAt.toISOString(),
    updated_at: product.updatedAt.toISOString(),
  };
}
