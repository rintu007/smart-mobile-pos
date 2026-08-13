import { Prisma } from "@prisma/client";
import * as identityService from "@/modules/identity/service";
import * as storesService from "@/modules/stores/service";
import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import type { CreateProductRequest } from "./schema";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

const UNIQUE_CONSTRAINT_VIOLATION = "P2002";

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

  // §2's dated correction: category_id/unit_id are optional this sprint, but when provided they
  // must reference a real row under this same tenant — the same tenant-scoped existence check
  // pos/service.ts already uses for a sale's product_id references.
  if (input.category_id) {
    const category = await repository.findCategoryById(tenantId, input.category_id);
    if (!category) {
      throw new ApiError(404, "NOT_FOUND", `Category ${input.category_id} not found.`);
    }
  }
  if (input.unit_id) {
    const unit = await repository.findUnitById(tenantId, input.unit_id);
    if (!unit) {
      throw new ApiError(404, "NOT_FOUND", `Unit ${input.unit_id} not found.`);
    }
  }

  let product;
  try {
    product = await repository.createProduct({ ...input, tenantId, createdBy, storeId });
  } catch (error) {
    // catalogue.md's BARCODE_ALREADY_ASSIGNED — the (tenantId, barcode) unique constraint is the
    // backstop, translated to the documented error code rather than a generic 500, same pattern
    // identity/service.ts's onboard() already established for its own unique-constraint catch.
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === UNIQUE_CONSTRAINT_VIOLATION) {
      const target = error.meta?.target as string[] | undefined;
      if (target?.includes("barcode")) {
        throw new ApiError(
          409,
          "BARCODE_ALREADY_ASSIGNED",
          `Barcode ${input.barcode} is already assigned to another product.`,
        );
      }
      // SKU_ALREADY_ASSIGNED: not in catalogue.md/error-catalogue.md yet — added here, and to both
      // documents in the same PR, as the natural sibling of BARCODE_ALREADY_ASSIGNED rather than
      // left to surface as an unhandled 500 for a schema-documented ("unique per tenant") case.
      if (target?.includes("sku")) {
        throw new ApiError(
          409,
          "SKU_ALREADY_ASSIGNED",
          `SKU ${input.sku} is already assigned to another product.`,
        );
      }
    }
    throw error;
  }

  return {
    id: product.id,
    name: product.name,
    // BigInt has no native JSON representation — safe to convert to Number here since realistic
    // minor-unit prices are nowhere near Number.MAX_SAFE_INTEGER (2^53 - 1).
    price_minor_units: Number(product.priceMinorUnits),
    category_id: product.categoryId,
    unit_id: product.unitId,
    sku: product.sku,
    barcode: product.barcode,
    hsn_sac_code: product.hsnSacCode,
    created_at: product.createdAt.toISOString(),
    updated_at: product.updatedAt.toISOString(),
  };
}
