import { prisma } from "@/core/db/client";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

export function listByTenant(tenantId: string) {
  return prisma.store.findMany({
    where: { tenantId, deactivatedAt: null },
    orderBy: { createdAt: "asc" },
  });
}
