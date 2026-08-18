import { randomUUID } from "node:crypto";
import { PrismaClient } from "@prisma/client";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { pushOperations } from "@/modules/sync/service";
import { getStockBalance } from "@/modules/stock-movements/service";
import type { SyncPushOperation } from "@/modules/sync/schema";

/**
 * Sprint 41 (backlog.md M4 item 6) — docs/13-offline-sync/test-plan.md §2's "N-device fuzzed
 * interleaving (100 runs)" row. Deliberately **not** matched by `vitest.integration.config.ts`'s
 * default `include` (it excludes `*.nightly.test.ts` explicitly) — offline-test-suite.md §3 places
 * this specific case on the nightly/release-candidate tier, not every PR, because it is
 * non-deterministic by design and 100 runs materially exceeds the PR-feedback budget
 * ci-pipeline.md sets. Backlog item 7 (Nightly CI pipeline) wires this file into a new
 * `nightly.yml`, run against the same `postgres:15` container mechanism `fast-integration` already
 * uses — this file is ready for that, not stubbed ahead of it (the same posture Sprint 40 set for
 * `fast-integration` itself before Sprint 40 built it).
 *
 * A real, related gap found while writing this test: test-plan.md §2's own row names
 * "opening/sale/adjustment movements" as the fuzzed operation mix, but no `adjustment` sync-push
 * operation type exists at all — `POST /stock-movements` (the only way to create an `adjustment`
 * movement) is a direct, online-only endpoint, never wired into `sync/schema.ts`'s operation-type
 * union. Fuzzed here across the two movement types that *are* sync-pushable: `opening` (via
 * `product.create`'s `initial_quantity`) and `sale` (via `sale.create`) — a corrected, dated scope
 * note in test-plan.md §2 explains this rather than silently substituting without comment.
 */

let prisma: PrismaClient;

beforeAll(async () => {
  prisma = new PrismaClient();
  await prisma.$connect();
});

afterAll(async () => {
  await prisma.$disconnect();
});

async function seedMinimalTenant(label: string) {
  const tenantId = randomUUID();
  const storeId = randomUUID();
  const userId = randomUUID();
  const authUserId = randomUUID();
  await prisma.$transaction(async (tx) => {
    await tx.tenant.create({ data: { id: tenantId, name: `Fuzz Tenant ${label}`, createdBy: userId } });
    await tx.user.create({
      data: { id: userId, tenantId, authUserId, displayName: `Fuzz Owner ${label}`, createdBy: userId },
    });
    await tx.store.create({ data: { id: storeId, tenantId, name: `Fuzz Store ${label}`, createdBy: userId } });
    await tx.userStoreRole.create({
      data: { id: randomUUID(), tenantId, userId, storeId, role: "owner", assignedBy: userId },
    });
    // `settingsService.getMoneySettings` (which `createSale` needs for every push) 404s with no row
    // at all — found live the first time this test ran, unlike `seedTenant`, this minimal fixture
    // has to create one itself.
    await tx.shopSettings.create({
      data: {
        tenantId,
        taxMode: "unregistered",
        pricingMode: "inclusive",
        roundingRule: "round_half_up",
        discountAutoApprovalThresholdMinorUnits: 50000n,
        returnAutoApprovalThresholdMinorUnits: 100000n,
        createdBy: userId,
      },
    });
  });
  return { tenantId, storeId, authUserId };
}

function randomInt(min: number, max: number): number {
  return min + Math.floor(Math.random() * (max - min + 1));
}

function shuffled<T>(items: T[]): T[] {
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j]!, copy[i]!];
  }
  return copy;
}

const RUNS = 100;
const DEVICE_COUNT = 5;
const OPENING_QUANTITY = 50;

describe("N-device fuzzed concurrent-composition (test-plan.md §2, 100 runs)", () => {
  it(
    `final stock balance is order-independent across ${RUNS} randomised interleavings`,
    async () => {
      for (let run = 0; run < RUNS; run++) {
        const tenant = await seedMinimalTenant(`FZ${run}`);
        const productId = randomUUID();
        await pushOperations(tenant.authUserId, tenant.tenantId, {
          operations: [
            {
              type: "product.create",
              client_operation_id: randomUUID(),
              payload: { id: productId, name: `Fuzz Product ${run}`, price_minor_units: 1000, initial_quantity: OPENING_QUANTITY },
            },
          ],
        });

        // 5 simulated devices, each an independent batch of sale.create ops against the same
        // product — pushed in a randomised per-run order, the fuzzed "interleaving."
        let totalSold = 0;
        const deviceBatches: SyncPushOperation[][] = Array.from({ length: DEVICE_COUNT }, () => {
          const opCount = randomInt(1, 4);
          return Array.from({ length: opCount }, () => {
            const quantity = randomInt(1, 3);
            totalSold += quantity;
            const id = randomUUID();
            return {
              type: "sale.create",
              client_operation_id: randomUUID(),
              payload: {
                id,
                store_id: tenant.storeId,
                provisional_invoice_number: `PROV-${id.slice(0, 8)}`,
                line_items: [{ product_id: productId, quantity, client_unit_price_minor_units: 1000 }],
                payments: [{ method: "cash", amount_minor_units: 1000 * quantity }],
              },
            } satisfies SyncPushOperation;
          });
        });

        for (const batch of shuffled(deviceBatches)) {
          const { results } = await pushOperations(tenant.authUserId, tenant.tenantId, { operations: batch });
          for (const result of results) {
            expect(result.status).toBe("accepted");
          }
        }

        const { balance } = await getStockBalance(tenant.tenantId, productId);
        expect(balance).toBe(OPENING_QUANTITY - totalSold);
      }
    },
    10 * 60 * 1000,
  );
});
