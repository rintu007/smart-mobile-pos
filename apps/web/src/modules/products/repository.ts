import { prisma } from "@/core/db/client";
import type { CreateProductRequest } from "./schema";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

export function createProduct(
  input: CreateProductRequest & { tenantId: string; createdBy: string },
) {
  // Upsert-on-id, same idempotent-replay mechanism as identity/repository.ts's createOnboarding —
  // docs/11-api/api-principles.md §3.
  return prisma.product.upsert({
    where: { id: input.id },
    create: {
      id: input.id,
      tenantId: input.tenantId,
      name: input.name,
      priceMinorUnits: BigInt(input.price_minor_units),
      createdBy: input.createdBy,
    },
    update: {},
  });
}
