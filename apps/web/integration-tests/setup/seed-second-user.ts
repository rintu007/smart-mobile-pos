import { randomUUID } from "node:crypto";
import type { PrismaClient } from "@prisma/client";

/**
 * Sprint 41 (backlog.md M4 item 6) — a second identity under an already-`seedTenant`-seeded
 * tenant/store, standing in for "a second device" in the adversarial suite's concurrent-composition
 * tests. No `devices` table exists (cross-tenant-isolation.test.ts, Sprint 40, already named this
 * gap) — `created_by`/the acting `authUserId` is this codebase's standing device-substitute, so
 * "two devices" is modelled here as two distinct users under the same tenant/store, matching that
 * precedent rather than inventing a new one.
 */
export async function seedSecondUser(
  prisma: PrismaClient,
  tenantId: string,
  storeId: string,
  label: string,
  role: "cashier" | "manager" | "owner" = "cashier",
) {
  const userId = randomUUID();
  const authUserId = randomUUID();
  await prisma.user.create({
    data: { id: userId, tenantId, authUserId, displayName: `Device ${label}`, createdBy: userId },
  });
  await prisma.userStoreRole.create({
    data: { id: randomUUID(), tenantId, userId, storeId, role, assignedBy: userId },
  });
  return { userId, authUserId };
}
