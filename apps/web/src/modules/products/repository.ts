import { prisma } from "@/core/db/client";
import type { CreateProductRequest } from "./schema";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

// docs/modules/products/specification.md §2 — a provided category_id/unit_id must reference a
// row that exists under the *same* tenant (tenant-scoped, same as sync/pos's own product-existence
// checks), never validated by name/global uniqueness.
export function findCategoryById(tenantId: string, id: string) {
  return prisma.category.findFirst({ where: { id, tenantId } });
}

export function findUnitById(tenantId: string, id: string) {
  return prisma.unit.findFirst({ where: { id, tenantId } });
}

export function createProduct(
  input: CreateProductRequest & { tenantId: string; createdBy: string; storeId: string },
) {
  // Upsert-on-id, same idempotent-replay mechanism as identity/repository.ts's createOnboarding —
  // docs/11-api/api-principles.md §3. Wrapped in a transaction with the opening stock movement
  // (backlog.md item 7) so the product and its ledger baseline are created atomically or not at
  // all — docs/modules/inventory/specification.md §1. The movement reuses the product's own id as
  // its idempotency key: a 1:1 relationship, so a replay of the same creation request naturally
  // no-ops both rows together rather than needing separate insert-vs-update detection.
  return prisma.$transaction(async (tx) => {
    const product = await tx.product.upsert({
      where: { id: input.id },
      create: {
        id: input.id,
        tenantId: input.tenantId,
        name: input.name,
        priceMinorUnits: BigInt(input.price_minor_units),
        categoryId: input.category_id,
        unitId: input.unit_id,
        sku: input.sku,
        barcode: input.barcode,
        hsnSacCode: input.hsn_sac_code,
        createdBy: input.createdBy,
      },
      update: {},
    });

    await tx.stockMovement.upsert({
      where: { id: input.id },
      create: {
        id: input.id,
        tenantId: input.tenantId,
        storeId: input.storeId,
        productId: product.id,
        quantityDelta: input.initial_quantity ?? 0,
        movementType: "opening",
        createdBy: input.createdBy,
      },
      update: {},
    });

    // DR-025 / audit-logging.md §1's Phase 14 correction (found unfixed Sprint 43, backlog.md M4
    // item 8): every stock_movements row gets its own paired audit_log entry, not only adjustments —
    // this 'opening' movement was the first of the four movement types found still missing one.
    // Reuses the movement's own id (== this product's id, the same 1:1 relationship the movement
    // upsert above already establishes), same upsert-on-id idempotent-replay shape.
    await tx.auditLog.upsert({
      where: { id: input.id },
      create: {
        id: input.id,
        tenantId: input.tenantId,
        storeId: input.storeId,
        actorUserId: input.createdBy,
        action: "stock_movement.opening",
        entityType: "stock_movement",
        entityId: input.id,
        afterState: {
          id: input.id,
          product_id: product.id,
          quantity_delta: input.initial_quantity ?? 0,
          movement_type: "opening",
        },
      },
      update: {},
    });

    return product;
  });
}

export interface ProductCursor {
  updatedAt: Date;
  id: string;
}

export interface ListProductsFilters {
  search?: string;
  categoryId?: string;
  barcode?: string;
}

// (updated_at, id) cursor, per api-principles.md §4's Tier 1 convention (matches sync/repository.ts's
// own listProductsForSync exactly — this is the second, direct-endpoint reader of the same table).
// Fetches limit + 1 as a peek, same off-by-one fix applied from the start.
export function listProducts(
  tenantId: string,
  filters: ListProductsFilters,
  cursor: ProductCursor | null,
  limit: number,
) {
  // `search` and the cursor tuple-comparison each need their own OR clause — combined via AND,
  // never as sibling `OR` object keys, which would silently collide (the second overwriting the
  // first) since a JS object can only hold one `OR` key.
  return prisma.product.findMany({
    where: {
      tenantId,
      ...(filters.categoryId ? { categoryId: filters.categoryId } : {}),
      ...(filters.barcode ? { barcode: filters.barcode } : {}),
      AND: [
        ...(filters.search
          ? [
              {
                OR: [
                  { name: { contains: filters.search, mode: "insensitive" as const } },
                  { sku: { contains: filters.search, mode: "insensitive" as const } },
                ],
              },
            ]
          : []),
        ...(cursor
          ? [
              {
                OR: [
                  { updatedAt: { gt: cursor.updatedAt } },
                  { updatedAt: cursor.updatedAt, id: { gt: cursor.id } },
                ],
              },
            ]
          : []),
      ],
    },
    orderBy: [{ updatedAt: "asc" }, { id: "asc" }],
    take: limit + 1,
  });
}
