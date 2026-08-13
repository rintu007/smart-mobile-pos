import { prisma } from "@/core/db/client";
import type { CreateUnitRequest } from "./schema";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

export function createUnit(
  input: CreateUnitRequest & { tenantId: string; createdBy: string },
) {
  // Upsert-on-id, same idempotent-replay mechanism as every other M0/M1 creation endpoint —
  // docs/11-api/api-principles.md §3.
  return prisma.unit.upsert({
    where: { id: input.id },
    create: {
      id: input.id,
      tenantId: input.tenantId,
      name: input.name,
      symbol: input.symbol,
      allowsFractional: input.allows_fractional,
      createdBy: input.createdBy,
    },
    update: {},
  });
}

export interface UnitCursor {
  createdAt: Date;
  id: string;
}

// (created_at, id) cursor, same reasoning as categories/repository.ts — no `updated_at` column
// exists yet (added once PATCH lands). Fetches limit + 1 as a peek, the off-by-one fix applied
// from the start (sync/repository.ts's own pull endpoint needed it found live; categories and now
// units get it correct from the first line).
export function listUnits(tenantId: string, cursor: UnitCursor | null, limit: number) {
  return prisma.unit.findMany({
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
