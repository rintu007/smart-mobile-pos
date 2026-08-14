import { prisma } from "@/core/db/client";
import type { Prisma } from "@prisma/client";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

export function findSettings(tenantId: string) {
  return prisma.shopSettings.findUnique({ where: { tenantId } });
}

// Conditional update, gated on the row's own `updatedAt` still matching `expectedUpdatedAt` —
// docs/modules/settings/specification.md §2's whole-row optimistic concurrency (conflict-resolution.md
// §4). `count === 0` means either the row doesn't exist (checked separately by the caller before
// this is reached) or a concurrent write landed first — the caller distinguishes those cases itself
// since it already fetched the row once to run §5's cross-field validation.
export async function updateSettingsIfUnchanged(
  tenantId: string,
  expectedUpdatedAt: Date,
  data: Prisma.ShopSettingsUpdateInput,
) {
  const result = await prisma.shopSettings.updateMany({
    where: { tenantId, updatedAt: expectedUpdatedAt },
    data,
  });
  return result.count > 0;
}
