import { randomUUID } from "node:crypto";
import { PrismaClient } from "@prisma/client";
import { createTestPrismaClient } from "./setup/create-test-prisma-client";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { checkRateLimit } from "@/core/rate-limit/service";

/**
 * Sprint 45 (docs/11-api/rate-limiting.md) — the fixed-window limiter behind
 * `core/auth/session.ts`'s `requirePermission`, tested directly against a real Postgres
 * connection (the `rate_limit_buckets` table), not through an HTTP request — `requirePermission`
 * needs a real Supabase-verified JWT, which (per Sprint 41's own established pattern) this suite
 * doesn't fake; the property under test is the counter's own correctness, which doesn't need HTTP
 * at all to prove.
 */

let prisma: PrismaClient;

beforeAll(async () => {
  prisma = createTestPrismaClient();
  await prisma.$connect();
});

afterAll(async () => {
  await prisma.$disconnect();
});

describe("Rate limiting — fixed-window counter (rate-limiting.md §1/§2)", () => {
  it("allows exactly `limit` calls within a window, then rejects with RATE_LIMITED + Retry-After", async () => {
    const scope = `test-mutating:${randomUUID()}`;

    for (let i = 0; i < 5; i++) {
      await expect(checkRateLimit(scope, 5, 60)).resolves.toBeUndefined();
    }

    await expect(checkRateLimit(scope, 5, 60)).rejects.toMatchObject({
      status: 429,
      code: "RATE_LIMITED",
      headers: { "Retry-After": expect.any(String) },
    });
  });

  it("a rejection's Retry-After is a positive integer no larger than the window", async () => {
    const scope = `test-window:${randomUUID()}`;
    await checkRateLimit(scope, 1, 10);

    try {
      await checkRateLimit(scope, 1, 10);
      expect.unreachable("expected RATE_LIMITED");
    } catch (error) {
      const retryAfter = Number((error as { headers: { "Retry-After": string } }).headers["Retry-After"]);
      expect(retryAfter).toBeGreaterThan(0);
      expect(retryAfter).toBeLessThanOrEqual(10);
    }
  });

  it("different scopes never share a bucket, even at the identical limit", async () => {
    const scopeA = `test-isolation-a:${randomUUID()}`;
    const scopeB = `test-isolation-b:${randomUUID()}`;

    await checkRateLimit(scopeA, 1, 60);
    // scopeA is now at its limit — scopeB must be entirely unaffected.
    await expect(checkRateLimit(scopeB, 1, 60)).resolves.toBeUndefined();
    await expect(checkRateLimit(scopeA, 1, 60)).rejects.toMatchObject({ code: "RATE_LIMITED" });
  });

  it("a new window resets the count — a scope limited in one window is allowed again in the next", async () => {
    const scope = `test-reset:${randomUUID()}`;

    await checkRateLimit(scope, 1, 1); // window = 1s, the tightest realistic value to keep this fast
    await expect(checkRateLimit(scope, 1, 1)).rejects.toMatchObject({ code: "RATE_LIMITED" });

    await new Promise((resolve) => setTimeout(resolve, 1100));

    await expect(checkRateLimit(scope, 1, 1)).resolves.toBeUndefined();
  });
});
