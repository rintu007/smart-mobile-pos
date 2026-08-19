import { PrismaClient } from "@prisma/client";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { eraseCustomer, deactivateCustomer } from "@/modules/customers/service";
import { seedTenant } from "./setup/seed-tenant";

/**
 * Sprint 46 (docs/12-security/privacy.md §4) — the erasure-on-request resolution that document
 * specified since Phase 12 but never had running code: an erasure request anonymises a `customers`
 * row (`name`/`phone` nulled) rather than deleting it, so every historical `sales.customer_id` FK
 * stays valid. Proven against a real Postgres connection, not by inspection — including the one
 * property a mocked unit test can't demonstrate: that a real foreign-key constraint genuinely
 * survives the erasure (there is no `ON DELETE` involved here at all — the row is never deleted —
 * but this proves the FK itself keeps resolving correctly afterward, not just that no error was
 * thrown).
 */

let prisma: PrismaClient;

beforeAll(async () => {
  prisma = new PrismaClient();
  await prisma.$connect();
});

afterAll(async () => {
  await prisma.$disconnect();
});

describe("Customer erasure (privacy.md §4)", () => {
  it("nulls name/phone, sets erased_at and deactivated_at, and the customer's historical sale keeps resolving", async () => {
    const tenant = await seedTenant(prisma, "CE1");

    const result = await eraseCustomer(tenant.tenantId, tenant.customerId);

    expect(result.name).toBeNull();
    expect(result.phone).toBeNull();
    expect(result.erased_at).not.toBeNull();

    const row = await prisma.customer.findUniqueOrThrow({ where: { id: tenant.customerId } });
    expect(row.name).toBeNull();
    expect(row.phone).toBeNull();
    expect(row.erasedAt).not.toBeNull();
    expect(row.deactivatedAt).not.toBeNull(); // wasn't deactivated before — erasure sets it.

    // The FK itself: seed-tenant.ts's own fixture sale references this exact customer id — still
    // resolvable, still pointing at the (now-anonymised) row, per privacy.md §4's whole reason for
    // anonymising instead of deleting.
    const sale = await prisma.sale.findUniqueOrThrow({ where: { id: tenant.saleId } });
    expect(sale.customerId).toBe(tenant.customerId);
  });

  it("preserves an already-deactivated customer's own deactivated_at rather than overwriting it", async () => {
    const tenant = await seedTenant(prisma, "CE2");
    const deactivated = await deactivateCustomer(tenant.tenantId, tenant.customerId);
    const originalDeactivatedAt = deactivated.deactivated_at;

    await eraseCustomer(tenant.tenantId, tenant.customerId);

    const row = await prisma.customer.findUniqueOrThrow({ where: { id: tenant.customerId } });
    expect(row.deactivatedAt?.toISOString()).toBe(originalDeactivatedAt);
  });

  it("is idempotent — a second erasure request on an already-erased customer is a pure no-op", async () => {
    const tenant = await seedTenant(prisma, "CE3");

    const first = await eraseCustomer(tenant.tenantId, tenant.customerId);
    const second = await eraseCustomer(tenant.tenantId, tenant.customerId);

    expect(second.erased_at).toBe(first.erased_at);
    expect(second).toEqual(first);
  });

  it("rejects a nonexistent customer with NOT_FOUND", async () => {
    const tenant = await seedTenant(prisma, "CE4");

    await expect(eraseCustomer(tenant.tenantId, "00000000-0000-4000-8000-000000000000")).rejects.toMatchObject({
      code: "NOT_FOUND",
    });
  });
});
