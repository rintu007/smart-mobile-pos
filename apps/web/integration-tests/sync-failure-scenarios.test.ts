import { randomUUID } from "node:crypto";
import { PrismaClient } from "@prisma/client";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { pushOperations } from "@/modules/sync/service";
import type { SyncPushOperation } from "@/modules/sync/schema";
import { seedTenant } from "./setup/seed-tenant";

/**
 * Sprint 41 (backlog.md M4 item 6) — the subset of failure-scenarios.md §1's 10 named scenarios
 * that are genuinely a **server** contract, testable against a real Postgres connection with no new
 * infrastructure. The other 9 are classified, not silently skipped — see
 * docs/13-offline-sync/test-plan.md §3's Sprint 41 correction for the full per-row reasoning:
 *
 * - "Connectivity lost mid-batch": the server-observable half of this row ("operations already
 *   acknowledged... stay Synced") is the exact same replay-safety guarantee
 *   sync-idempotent-replay.test.ts's "ambiguous-acknowledgement replay" case already proves — a
 *   second push of an already-committed operation is a no-op, never a duplicate or an error. The
 *   client-side half (scheduling a retry after a real severed connection) is a mobile SyncEngine
 *   concern needing a live server + fault-injecting proxy in front of it, not this suite.
 * - "Server rejects one item in a batch": built for real below — the one row this file adds.
 * - App killed mid-sync / device rebooted / storage full / schema version mismatch: mobile-only
 *   (`outbound_queue`, Drift, app-process lifecycle) — no server code path to test here at all.
 * - Device clock wrong: already proven by design in clock-and-ordering.md §4, no code test needed.
 * - Token expired while queued: needs a real Supabase Auth (GoTrue) JWT issuance/expiry, i.e. the
 *   full local Supabase CLI stack Sprint 40 already named and deferred for the Realtime extension,
 *   for the same reason.
 * - Same account on two devices / queue older than server retention: the failure-scenarios.md table
 *   itself already resolves both as "not a failure" / "not applicable, no such retention job exists"
 *   — nothing to test.
 */

let prisma: PrismaClient;

beforeAll(async () => {
  prisma = new PrismaClient();
  await prisma.$connect();
});

afterAll(async () => {
  await prisma.$disconnect();
});

describe("Failure scenarios — server-testable subset (failure-scenarios.md §1)", () => {
  it("server rejects one item in a batch: every other operation is still applied independently", async () => {
    const tenant = await seedTenant(prisma, "FS1");
    const productId = randomUUID();
    await pushOperations(tenant.authUserId, tenant.tenantId, {
      operations: [
        {
          type: "product.create",
          client_operation_id: randomUUID(),
          payload: { id: productId, name: "FS1 Product", price_minor_units: 100000, initial_quantity: 5 },
        },
      ],
    });

    const goodSale1 = randomUUID();
    const badSale = randomUUID();
    const goodSale2 = randomUUID();
    const nonexistentProductId = randomUUID();

    function sale(id: string, forProductId: string): SyncPushOperation {
      return {
        type: "sale.create",
        client_operation_id: randomUUID(),
        payload: {
          id,
          store_id: tenant.storeId,
          provisional_invoice_number: `PROV-${id.slice(0, 8)}`,
          line_items: [{ product_id: forProductId, quantity: 1, client_unit_price_minor_units: 100000 }],
          payments: [{ method: "cash", amount_minor_units: 100000 }],
        },
      };
    }

    const { results } = await pushOperations(tenant.authUserId, tenant.tenantId, {
      operations: [sale(goodSale1, productId), sale(badSale, nonexistentProductId), sale(goodSale2, productId)],
    });

    expect(results[0]!.status).toBe("accepted");
    expect(results[0]!.entity_id).toBe(goodSale1);
    // sync-api.md §4's remapping for a sale referencing a product not (yet) synced/known.
    expect(results[1]!.status).toBe("rejected");
    expect(results[1]!.error?.code).toBe("DEPENDENCY_NOT_FOUND");
    expect(results[2]!.status).toBe("accepted");
    expect(results[2]!.entity_id).toBe(goodSale2);

    expect(await prisma.sale.findUnique({ where: { id: goodSale1 } })).not.toBeNull();
    expect(await prisma.sale.findUnique({ where: { id: goodSale2 } })).not.toBeNull();
    expect(await prisma.sale.findUnique({ where: { id: badSale } })).toBeNull();
  });
});
