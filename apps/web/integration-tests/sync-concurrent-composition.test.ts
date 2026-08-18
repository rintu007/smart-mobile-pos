import { randomUUID } from "node:crypto";
import { PrismaClient } from "@prisma/client";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { pushOperations } from "@/modules/sync/service";
import { getStockBalance } from "@/modules/stock-movements/service";
import type { SyncPushOperation } from "@/modules/sync/schema";
import { seedTenant } from "./setup/seed-tenant";
import { seedSecondUser } from "./setup/seed-second-user";

/**
 * Sprint 41 (backlog.md M4 item 6) — docs/13-offline-sync/test-plan.md §2, the 2-device-scale rows
 * (two-device oversell, both field-merge cases, creation collision); the fifth row, N-device fuzzed
 * interleaving (100 runs), is deliberately **not** here — see
 * sync-concurrent-composition.nightly.test.ts's own doc comment for why it's a separate,
 * not-yet-CI-wired file rather than slower cases mixed into this PR-blocking one.
 *
 * "Two devices" has no `devices` table to model against (tenant-isolation.md §2's already-named
 * gap) — modelled here as two distinct seeded users under the same tenant/store
 * (integration-tests/setup/seed-second-user.ts), matching this codebase's own standing precedent of
 * `created_by`/the acting user as the device substitute.
 */

let prisma: PrismaClient;

beforeAll(async () => {
  prisma = new PrismaClient();
  await prisma.$connect();
});

afterAll(async () => {
  await prisma.$disconnect();
});

function productOp(id: string, priceMinorUnits: number, initialQuantity: number): SyncPushOperation {
  return {
    type: "product.create",
    client_operation_id: randomUUID(),
    payload: { id, name: `Product ${id.slice(0, 8)}`, price_minor_units: priceMinorUnits, initial_quantity: initialQuantity },
  };
}

function saleOp(id: string, storeId: string, productId: string, unitPrice: number, quantity: number): SyncPushOperation {
  return {
    type: "sale.create",
    client_operation_id: randomUUID(),
    payload: {
      id,
      store_id: storeId,
      provisional_invoice_number: `PROV-${id.slice(0, 8)}`,
      line_items: [{ product_id: productId, quantity, client_unit_price_minor_units: unitPrice }],
      payments: [{ method: "cash", amount_minor_units: unitPrice * quantity }],
    },
  };
}

describe("Concurrent-composition tests (test-plan.md §2)", () => {
  it("two-device oversell: final balance is identical (-1) regardless of which device's sale syncs first", async () => {
    async function runScenario(label: string, order: "aFirst" | "bFirst") {
      const tenant = await seedTenant(prisma, label);
      const deviceA = await seedSecondUser(prisma, tenant.tenantId, tenant.storeId, `${label}-A`);
      const deviceB = await seedSecondUser(prisma, tenant.tenantId, tenant.storeId, `${label}-B`);
      const productId = randomUUID();
      await pushOperations(deviceA.authUserId, tenant.tenantId, {
        operations: [productOp(productId, 100000, 1)],
      });

      const saleA = saleOp(randomUUID(), tenant.storeId, productId, 100000, 1);
      const saleB = saleOp(randomUUID(), tenant.storeId, productId, 100000, 1);

      if (order === "aFirst") {
        const resultA = await pushOperations(deviceA.authUserId, tenant.tenantId, { operations: [saleA] });
        const resultB = await pushOperations(deviceB.authUserId, tenant.tenantId, { operations: [saleB] });
        expect(resultA.results[0]!.status).toBe("accepted");
        expect(resultB.results[0]!.status).toBe("accepted");
      } else {
        const resultB = await pushOperations(deviceB.authUserId, tenant.tenantId, { operations: [saleB] });
        const resultA = await pushOperations(deviceA.authUserId, tenant.tenantId, { operations: [saleA] });
        expect(resultB.results[0]!.status).toBe("accepted");
        expect(resultA.results[0]!.status).toBe("accepted");
      }

      // DR-005 — oversell is never blocked; both sales of the last unit succeed regardless of order.
      const { balance } = await getStockBalance(tenant.tenantId, productId);
      return balance;
    }

    const balanceOrderAFirst = await runScenario("CC1A", "aFirst");
    const balanceOrderBFirst = await runScenario("CC1B", "bFirst");

    expect(balanceOrderAFirst).toBe(-1);
    expect(balanceOrderBFirst).toBe(-1);
    expect(balanceOrderAFirst).toBe(balanceOrderBFirst);
  });

  it("field-edit non-overlap merge: two devices editing different fields both apply, no conflict", async () => {
    const tenant = await seedTenant(prisma, "CC2");
    const deviceA = await seedSecondUser(prisma, tenant.tenantId, tenant.storeId, "CC2-A");
    const deviceB = await seedSecondUser(prisma, tenant.tenantId, tenant.storeId, "CC2-B");
    const before = await prisma.customer.findUniqueOrThrow({ where: { id: tenant.customerId } });
    const conflictCountBefore = await prisma.customerFieldConflict.count({ where: { customerId: tenant.customerId } });

    const editNameOnly: SyncPushOperation = {
      type: "customer.update",
      client_operation_id: randomUUID(),
      payload: {
        id: tenant.customerId,
        base_updated_at: before.updatedAt.toISOString(),
        base_name: before.name,
        base_phone: before.phone,
        name: "Non-overlap Name",
        phone: before.phone,
      },
    };
    const editPhoneOnly: SyncPushOperation = {
      type: "customer.update",
      client_operation_id: randomUUID(),
      payload: {
        id: tenant.customerId,
        base_updated_at: before.updatedAt.toISOString(),
        base_name: before.name,
        base_phone: before.phone,
        name: before.name,
        phone: "9990001111",
      },
    };

    await pushOperations(deviceA.authUserId, tenant.tenantId, { operations: [editNameOnly] });
    await pushOperations(deviceB.authUserId, tenant.tenantId, { operations: [editPhoneOnly] });

    const after = await prisma.customer.findUniqueOrThrow({ where: { id: tenant.customerId } });
    expect(after.name).toBe("Non-overlap Name");
    expect(after.phone).toBe("9990001111");
    expect(await prisma.customerFieldConflict.count({ where: { customerId: tenant.customerId } })).toBe(
      conflictCountBefore,
    );
  });

  it("field-edit same-field collision: neither value silently wins, a field-level conflict is recorded", async () => {
    const tenant = await seedTenant(prisma, "CC3");
    const deviceA = await seedSecondUser(prisma, tenant.tenantId, tenant.storeId, "CC3-A");
    const deviceB = await seedSecondUser(prisma, tenant.tenantId, tenant.storeId, "CC3-B");
    const before = await prisma.customer.findUniqueOrThrow({ where: { id: tenant.customerId } });

    const basePayload = {
      base_updated_at: before.updatedAt.toISOString(),
      base_name: before.name,
      base_phone: before.phone,
      name: before.name,
    };
    const editA: SyncPushOperation = {
      type: "customer.update",
      client_operation_id: randomUUID(),
      payload: { id: tenant.customerId, ...basePayload, phone: "8880001111" },
    };
    const editB: SyncPushOperation = {
      type: "customer.update",
      client_operation_id: randomUUID(),
      payload: { id: tenant.customerId, ...basePayload, phone: "8880002222" },
    };

    await pushOperations(deviceA.authUserId, tenant.tenantId, { operations: [editA] });
    await pushOperations(deviceB.authUserId, tenant.tenantId, { operations: [editB] });

    const after = await prisma.customer.findUniqueOrThrow({ where: { id: tenant.customerId } });
    expect(after.phone).toBe("8880001111");

    // `currentValue: "8880001111"` alone is a specific enough filter that only this test's own new
    // conflict row can match it — no other row (including seed-tenant.ts's own pre-existing "phone"
    // conflict fixture for this same customer, which never sets `currentValue` to this) could.
    const conflicts = await prisma.customerFieldConflict.findMany({
      where: { customerId: tenant.customerId, field: "phone", currentValue: "8880001111" },
    });
    expect(conflicts).toHaveLength(1);
    expect(conflicts[0]!.attemptedValue).toBe("8880002222");
  });

  it("creation collision: the second device's customer with the same phone is rejected with PHONE_ALREADY_ASSIGNED", async () => {
    const tenant = await seedTenant(prisma, "CC4");
    const deviceA = await seedSecondUser(prisma, tenant.tenantId, tenant.storeId, "CC4-A");
    const deviceB = await seedSecondUser(prisma, tenant.tenantId, tenant.storeId, "CC4-B");
    const phone = "7770001111";
    const customerA = randomUUID();
    const customerB = randomUUID();

    const resultA = await pushOperations(deviceA.authUserId, tenant.tenantId, {
      operations: [{ type: "customer.create", client_operation_id: randomUUID(), payload: { id: customerA, name: "First", phone } }],
    });
    const resultB = await pushOperations(deviceB.authUserId, tenant.tenantId, {
      operations: [{ type: "customer.create", client_operation_id: randomUUID(), payload: { id: customerB, name: "Second", phone } }],
    });

    expect(resultA.results[0]!.status).toBe("accepted");
    expect(resultB.results[0]!.status).toBe("rejected");
    expect(resultB.results[0]!.error?.code).toBe("PHONE_ALREADY_ASSIGNED");

    expect(await prisma.customer.count({ where: { tenantId: tenant.tenantId, phone } })).toBe(1);
    expect(await prisma.customer.findUnique({ where: { id: customerB } })).toBeNull();
  });
});
