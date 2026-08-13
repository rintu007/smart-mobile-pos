import { prisma } from "@/core/db/client";
import type { CreateCategoryRequest } from "./schema";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

export function createCategory(
  input: CreateCategoryRequest & { tenantId: string; createdBy: string },
) {
  // Upsert-on-id, same idempotent-replay mechanism as every other M0 creation endpoint —
  // docs/11-api/api-principles.md §3.
  return prisma.category.upsert({
    where: { id: input.id },
    create: {
      id: input.id,
      tenantId: input.tenantId,
      name: input.name,
      createdBy: input.createdBy,
    },
    update: {},
  });
}

export interface CategoryCursor {
  createdAt: Date;
  id: string;
}

// (created_at, id) cursor — categories/specification.md §4: no `updated_at` column exists yet
// (added once PATCH lands), so this table cursors on created_at rather than the usual Tier 1
// updated_at convention. Fetches limit + 1 as a peek, same off-by-one fix sync/repository.ts's
// own pull endpoint needed — applied here from the start rather than found live a second time.
export function listCategories(tenantId: string, cursor: CategoryCursor | null, limit: number) {
  return prisma.category.findMany({
    where: {
      tenantId,
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
