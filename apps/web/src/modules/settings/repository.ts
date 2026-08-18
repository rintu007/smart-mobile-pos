import { randomUUID } from "node:crypto";
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
//
// Wrapped in a transaction with a paired audit_log entry (found unfixed Sprint 43, backlog.md M4
// item 8 — audit-logging.md §1's "settings change affecting tax/pricing/thresholds" row had no
// implementation anywhere) — written only when the conditional update actually applied, never for a
// no-op `SETTINGS_CONFLICT` attempt. `afterState` is the caller's own already-JSON-safe view of just
// the fields this request changed, not the raw Prisma `data` shape (which carries BigInt values that
// don't serialize).
export async function updateSettingsIfUnchanged(
  tenantId: string,
  expectedUpdatedAt: Date,
  data: Prisma.ShopSettingsUpdateInput,
  actorUserId: string,
  changedFields: Record<string, unknown>,
) {
  return prisma.$transaction(async (tx) => {
    const result = await tx.shopSettings.updateMany({
      where: { tenantId, updatedAt: expectedUpdatedAt },
      data,
    });
    if (result.count === 0) {
      return false;
    }

    await tx.auditLog.create({
      data: {
        id: randomUUID(),
        tenantId,
        actorUserId,
        action: "settings.updated",
        entityType: "shop_settings",
        entityId: tenantId,
        afterState: changedFields as Prisma.InputJsonObject,
      },
    });

    return true;
  });
}
