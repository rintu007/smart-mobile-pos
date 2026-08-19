import { prisma } from "@/core/db/client";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

// Sprint 45 (docs/11-api/rate-limiting.md) — a fixed-window counter. `key` already embeds the
// window's own start (via the caller in service.ts), so an upsert here is the atomic
// increment-or-create every concurrent request to the same window needs; two requests racing to
// create the same window's row resolve to the same correct count either way, the same
// upsert-on-id idempotency shape this codebase already uses for every other id-keyed creation.
export function incrementBucket(key: string, windowEnd: Date) {
  return prisma.rateLimitBucket.upsert({
    where: { key },
    create: { key, count: 1, windowEnd },
    update: { count: { increment: 1 } },
  });
}

// Opportunistic cleanup (service.ts calls this probabilistically, not on every request) — bounds
// this table's growth without a scheduled job, proportionate to a solo-founder-scale pilot. Never
// deletes a bucket that could still be checked against (only windows already fully in the past).
export function deleteExpiredBuckets(before: Date) {
  return prisma.rateLimitBucket.deleteMany({ where: { windowEnd: { lt: before } } });
}
