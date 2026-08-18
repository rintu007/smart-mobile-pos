import { randomUUID } from "node:crypto";
import { PrismaClient } from "@prisma/client";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { pushOperations } from "@/modules/sync/service";
import type { SyncPushOperation } from "@/modules/sync/schema";
import { seedTenant } from "./setup/seed-tenant";

/**
 * Sprint 41 (backlog.md M4 item 6) — docs/13-offline-sync/test-plan.md §1, the three idempotent-
 * replay cases, run against a real Postgres connection (the same `fast-integration` job / container
 * Sprint 40's cross-tenant suite already uses) by calling `pushOperations` in-process, the same way
 * every entity's own `POST` endpoint ultimately does — no HTTP layer, no toxiproxy: replay safety is
 * a server-observable property (does a second push of an already-committed operation produce the
 * same result, never a duplicate), not a network-layer one. See offline-test-suite.md §2 for why
 * this suite needs no fault-injecting proxy at all for this specific test-plan.md section.
 *
 * Building this suite for real (not mocked — `sync/service.test.ts`'s existing suite mocks every
 * downstream service, so it has never actually exercised a second write against the same row) found
 * a genuine gap: `pos/service.ts`'s `createSale` and `returns/service.ts`'s `createReturn`/
 * `approveReturn` each had a read-then-write idempotent-replay check (`findXById`, then create/
 * transition) that is not atomic — true concurrent replays (the "single-operation N-times replay"
 * case below, run with real overlapping requests via `Promise.all`, not sequential awaits) could
 * both pass the check before either committed, and the losing call then threw a raw Postgres unique-
 * violation instead of returning the idempotent result. Fixed in the same pass by catching that
 * specific violation and re-fetching, the same catch-and-translate shape `customers/service.ts`'s
 * `translatePhoneConflict` and `products/service.ts`'s `BARCODE_ALREADY_ASSIGNED` handling already
 * established for this class of race — `product.create`/`customer.create` never had this gap, since
 * both already use an id-keyed `upsert` rather than find-then-create.
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

describe("Idempotent-replay tests (test-plan.md §1)", () => {
  it("full-queue double replay: server state after a second identical pass matches the first exactly", async () => {
    const tenant = await seedTenant(prisma, "IR1");

    // Setup, outside the replayed batch: two products priced high enough that a full-line return
    // exceeds shop_settings.return_auto_approval_threshold_minor_units (100000, seed-tenant.ts),
    // landing at pending_approval so the batch below has a real approve/reject target each.
    // A third setup product/sale exists purely so the batch's own `return.create` op below has a
    // line item with quantity still remaining — `seedTenant`'s own fixture sale (`tenant.saleId`)
    // already has its one line item fully consumed by the fixture's own pre-built return, found
    // live the first time this test ran (`RETURN_QUANTITY_EXCEEDS_SOLD`, 0 remaining).
    const setupProduct1 = randomUUID();
    const setupProduct2 = randomUUID();
    const setupProduct3 = randomUUID();
    await pushOperations(tenant.authUserId, tenant.tenantId, {
      operations: [
        productOp(setupProduct1, 250000, 5),
        productOp(setupProduct2, 250000, 5),
        productOp(setupProduct3, 100000, 5),
      ],
    });
    const setupSale1 = randomUUID();
    const setupSale2 = randomUUID();
    const setupSale3 = randomUUID();
    await pushOperations(tenant.authUserId, tenant.tenantId, {
      operations: [
        saleOp(setupSale1, tenant.storeId, setupProduct1, 250000, 1),
        saleOp(setupSale2, tenant.storeId, setupProduct2, 250000, 1),
        saleOp(setupSale3, tenant.storeId, setupProduct3, 100000, 1),
      ],
    });
    const sale1 = await prisma.sale.findUniqueOrThrow({ where: { id: setupSale1 }, include: { lineItems: true } });
    const sale2 = await prisma.sale.findUniqueOrThrow({ where: { id: setupSale2 }, include: { lineItems: true } });
    const sale3 = await prisma.sale.findUniqueOrThrow({ where: { id: setupSale3 }, include: { lineItems: true } });
    const pendingReturnToApprove = randomUUID();
    const pendingReturnToReject = randomUUID();
    await pushOperations(tenant.authUserId, tenant.tenantId, {
      operations: [
        {
          type: "return.create",
          client_operation_id: randomUUID(),
          payload: {
            id: pendingReturnToApprove,
            original_sale_id: setupSale1,
            line_items: [{ original_sale_line_item_id: sale1.lineItems[0]!.id, quantity: 1 }],
          },
        },
        {
          type: "return.create",
          client_operation_id: randomUUID(),
          payload: {
            id: pendingReturnToReject,
            original_sale_id: setupSale2,
            line_items: [{ original_sale_line_item_id: sale2.lineItems[0]!.id, quantity: 1 }],
          },
        },
      ],
    });
    const decidable1 = await prisma.return.findUniqueOrThrow({ where: { id: pendingReturnToApprove } });
    const decidable2 = await prisma.return.findUniqueOrThrow({ where: { id: pendingReturnToReject } });
    expect(decidable1.status).toBe("pending_approval");
    expect(decidable2.status).toBe("pending_approval");

    const currentCustomer = await prisma.customer.findUniqueOrThrow({ where: { id: tenant.customerId } });

    // The 10-op mixed batch itself (test-plan.md §1's "≥10 mixed operations: sales, returns,
    // approvals, catalogue edits" — no `product.update`/`category.*` push operation type exists yet
    // (only `product.create`; M1's own deferred PATCH/DELETE, sync-engine/specification.md §1), so
    // `customer.update` stands in as this batch's client-editable-entity edit).
    const batchProduct1 = randomUUID();
    const batchProduct2 = randomUUID();
    const batchSale1 = randomUUID();
    const batchSale2 = randomUUID();
    const newReturn = randomUUID();
    const operations: SyncPushOperation[] = [
      productOp(batchProduct1, 100000, 3),
      productOp(batchProduct2, 100000, 3),
      { type: "customer.create", client_operation_id: randomUUID(), payload: { id: randomUUID(), name: "Batch Customer 1", phone: "9111100001" } },
      { type: "customer.create", client_operation_id: randomUUID(), payload: { id: randomUUID(), name: "Batch Customer 2", phone: "9111100002" } },
      {
        type: "customer.update",
        client_operation_id: randomUUID(),
        payload: {
          id: tenant.customerId,
          base_updated_at: currentCustomer.updatedAt.toISOString(),
          base_name: currentCustomer.name,
          base_phone: currentCustomer.phone,
          name: "Renamed via replay batch",
          phone: currentCustomer.phone,
        },
      },
      saleOp(batchSale1, tenant.storeId, batchProduct1, 100000, 1),
      saleOp(batchSale2, tenant.storeId, batchProduct2, 100000, 1),
      {
        type: "return.create",
        client_operation_id: randomUUID(),
        payload: {
          id: newReturn,
          original_sale_id: setupSale3,
          line_items: [{ original_sale_line_item_id: sale3.lineItems[0]!.id, quantity: 1 }],
        },
      },
      { type: "return.approve", client_operation_id: randomUUID(), payload: { id: pendingReturnToApprove } },
      { type: "return.reject", client_operation_id: randomUUID(), payload: { id: pendingReturnToReject, reason: "Customer changed mind" } },
    ];
    expect(operations).toHaveLength(10);

    const firstPass = await pushOperations(tenant.authUserId, tenant.tenantId, { operations });
    expect(firstPass.results.every((result) => result.status === "accepted")).toBe(true);

    const productCountAfterFirst = await prisma.product.count({ where: { tenantId: tenant.tenantId } });
    const customerCountAfterFirst = await prisma.customer.count({ where: { tenantId: tenant.tenantId } });
    const saleCountAfterFirst = await prisma.sale.count({ where: { tenantId: tenant.tenantId } });
    const returnCountAfterFirst = await prisma.return.count({ where: { tenantId: tenant.tenantId } });

    // Replay: the identical batch, second pass — idempotency.md §3's exit-criterion proof, exercised
    // for real against a real database for the first time in this project's history.
    const secondPass = await pushOperations(tenant.authUserId, tenant.tenantId, { operations });
    expect(secondPass.results).toEqual(firstPass.results);

    expect(await prisma.product.count({ where: { tenantId: tenant.tenantId } })).toBe(productCountAfterFirst);
    expect(await prisma.customer.count({ where: { tenantId: tenant.tenantId } })).toBe(customerCountAfterFirst);
    expect(await prisma.sale.count({ where: { tenantId: tenant.tenantId } })).toBe(saleCountAfterFirst);
    expect(await prisma.return.count({ where: { tenantId: tenant.tenantId } })).toBe(returnCountAfterFirst);

    const finalCustomer = await prisma.customer.findUniqueOrThrow({ where: { id: tenant.customerId } });
    expect(finalCustomer.name).toBe("Renamed via replay batch");
    const approvedReturn = await prisma.return.findUniqueOrThrow({ where: { id: pendingReturnToApprove } });
    const rejectedReturn = await prisma.return.findUniqueOrThrow({ where: { id: pendingReturnToReject } });
    expect(approvedReturn.status).toBe("completed");
    expect(rejectedReturn.status).toBe("rejected");
  });

  it("single-operation N-times replay: 5 genuinely concurrent pushes of the same sale.create produce exactly one sale", async () => {
    const tenant = await seedTenant(prisma, "IR2");
    const productId = randomUUID();
    await pushOperations(tenant.authUserId, tenant.tenantId, { operations: [productOp(productId, 100000, 10)] });

    const saleId = randomUUID();
    const op = saleOp(saleId, tenant.storeId, productId, 100000, 1);

    // A tight client retry bug, modelled as genuinely overlapping requests (Promise.all), not
    // sequential awaits — this is what actually exercises the read-then-write race the doc comment
    // above this test file explains and pos/service.ts's own fix addresses.
    const outcomes = await Promise.all(
      Array.from({ length: 5 }, () => pushOperations(tenant.authUserId, tenant.tenantId, { operations: [op] })),
    );

    for (const outcome of outcomes) {
      expect(outcome.results).toHaveLength(1);
      expect(outcome.results[0]!.status).toBe("accepted");
      expect(outcome.results[0]!.entity_id).toBe(saleId);
    }

    expect(await prisma.sale.count({ where: { id: saleId } })).toBe(1);
    expect(await prisma.stockMovement.count({ where: { referenceType: "sale", referenceId: saleId } })).toBe(1);
  });

  it("ambiguous-acknowledgement replay: a second push after the server already committed returns the same result, no duplicate", async () => {
    const tenant = await seedTenant(prisma, "IR3");
    const productId = randomUUID();
    await pushOperations(tenant.authUserId, tenant.tenantId, { operations: [productOp(productId, 100000, 10)] });

    const saleId = randomUUID();
    const op = saleOp(saleId, tenant.storeId, productId, 100000, 1);

    const first = await pushOperations(tenant.authUserId, tenant.tenantId, { operations: [op] });
    expect(first.results[0]!.status).toBe("accepted");
    expect(first.results[0]!.entity_id).toBe(saleId);

    // The client never received the first response (it was "dropped after the server already
    // committed", failure-scenarios.md §1) and retries the identical operation.
    const retry = await pushOperations(tenant.authUserId, tenant.tenantId, { operations: [op] });
    expect(retry.results[0]!.status).toBe("accepted");
    expect(retry.results[0]!.entity_id).toBe(saleId);

    expect(await prisma.sale.count({ where: { id: saleId } })).toBe(1);
    expect(await prisma.stockMovement.count({ where: { referenceType: "sale", referenceId: saleId } })).toBe(1);
  });
});
