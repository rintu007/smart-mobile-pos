import { randomUUID } from "node:crypto";
import { PrismaClient } from "@prisma/client";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { pushOperations } from "@/modules/sync/service";
import * as stockMovementsService from "@/modules/stock-movements/service";
import * as settingsService from "@/modules/settings/service";
import type { SyncPushOperation } from "@/modules/sync/schema";
import { seedTenant } from "./setup/seed-tenant";

/**
 * Sprint 43 (backlog.md M4 item 8) — the OWASP checklist review against the real build (A09/
 * Security Logging and Monitoring Failures) found DR-025 ("every stock movement... produces exactly
 * one corresponding audit-log entry") was never actually implemented for three of the four
 * `stock_movements` movement types (`opening`/`sale`/`return`), and not at all for the fourth
 * (`adjustment`) — despite `audit-logging.md`'s own Phase 14 v0.1.1 correction already specifying
 * this exact requirement, and `implementation-log.md`'s Sprint 12 entry already naming it as "a
 * real, still-open gap." Fixed in the same pass across `products/repository.ts` (opening),
 * `pos/repository.ts` (sale), `returns/repository.ts` (return), and `stock-movements/repository.ts`
 * (adjustment) — this test proves each path for real, against a real Postgres connection, not by
 * inspection.
 */

let prisma: PrismaClient;

beforeAll(async () => {
  prisma = new PrismaClient();
  await prisma.$connect();
});

afterAll(async () => {
  await prisma.$disconnect();
});

describe("Audit log coverage — DR-025, one entry per stock_movements row (audit-logging.md §1)", () => {
  it("opening, sale, return, and adjustment movements each get their own paired audit_log entry", async () => {
    const tenant = await seedTenant(prisma, "AL1");

    // 'opening' — via product.create's initial_quantity.
    const productId = randomUUID();
    const opening: SyncPushOperation = {
      type: "product.create",
      client_operation_id: randomUUID(),
      payload: { id: productId, name: "Audit Product", price_minor_units: 100000, initial_quantity: 5 },
    };
    await pushOperations(tenant.authUserId, tenant.tenantId, { operations: [opening] });
    const openingAudits = await prisma.auditLog.findMany({
      where: { entityType: "stock_movement", entityId: productId },
    });
    expect(openingAudits).toHaveLength(1);
    expect(openingAudits[0]!.action).toBe("stock_movement.opening");

    // 'sale' — two line items, so two paired stock-movement audit entries plus one sale.completed.
    const saleId = randomUUID();
    const sale: SyncPushOperation = {
      type: "sale.create",
      client_operation_id: randomUUID(),
      payload: {
        id: saleId,
        store_id: tenant.storeId,
        provisional_invoice_number: `PROV-AL1-${saleId.slice(0, 8)}`,
        line_items: [
          { product_id: productId, quantity: 1, client_unit_price_minor_units: 100000 },
          { product_id: productId, quantity: 2, client_unit_price_minor_units: 100000 },
        ],
        payments: [{ method: "cash", amount_minor_units: 300000 }],
      },
    };
    await pushOperations(tenant.authUserId, tenant.tenantId, { operations: [sale] });
    const saleLineItems = await prisma.saleLineItem.findMany({ where: { saleId } });
    expect(saleLineItems).toHaveLength(2);
    const saleMovementAudits = await prisma.auditLog.findMany({
      where: { entityType: "stock_movement", entityId: { in: saleLineItems.map((i) => i.id) } },
    });
    expect(saleMovementAudits).toHaveLength(2);
    expect(saleMovementAudits.every((a) => a.action === "stock_movement.sale")).toBe(true);
    const saleCompletedAudit = await prisma.auditLog.findUnique({ where: { id: saleId } });
    expect(saleCompletedAudit?.action).toBe("sale.completed");

    // 'return' — a partial return of one line item.
    const returnId = randomUUID();
    const returnOp: SyncPushOperation = {
      type: "return.create",
      client_operation_id: randomUUID(),
      payload: {
        id: returnId,
        original_sale_id: saleId,
        line_items: [{ original_sale_line_item_id: saleLineItems[0]!.id, quantity: 1 }],
      },
    };
    await pushOperations(tenant.authUserId, tenant.tenantId, { operations: [returnOp] });
    const returnLineItems = await prisma.returnLineItem.findMany({ where: { returnId } });
    expect(returnLineItems).toHaveLength(1);
    const returnMovementAudits = await prisma.auditLog.findMany({
      where: { entityType: "stock_movement", entityId: { in: returnLineItems.map((i) => i.id) } },
    });
    expect(returnMovementAudits).toHaveLength(1);
    expect(returnMovementAudits[0]!.action).toBe("stock_movement.return");

    // 'adjustment' — the direct POST /stock-movements path, service-layer call.
    const adjustment = await stockMovementsService.createStockMovement(tenant.authUserId, tenant.tenantId, {
      id: randomUUID(),
      product_id: productId,
      quantity_delta: -1,
      movement_type: "adjustment",
      reason_code: "damage",
    });
    const adjustmentAudits = await prisma.auditLog.findMany({
      where: { entityType: "stock_movement", entityId: adjustment.id },
    });
    expect(adjustmentAudits).toHaveLength(1);
    expect(adjustmentAudits[0]!.action).toBe("stock_movement.adjustment");
  });

  it("a settings change writes exactly one audit_log entry for the fields actually changed", async () => {
    const tenant = await seedTenant(prisma, "AL2");
    const before = await prisma.shopSettings.findUniqueOrThrow({ where: { tenantId: tenant.tenantId } });

    await settingsService.updateSettings(tenant.authUserId, tenant.tenantId, {
      client_operation_id: randomUUID(),
      base_updated_at: before.updatedAt.toISOString(),
      rounding_rule: "round_half_even",
    });

    const settingsAudits = await prisma.auditLog.findMany({
      where: { entityType: "shop_settings", entityId: tenant.tenantId },
    });
    expect(settingsAudits).toHaveLength(1);
    expect(settingsAudits[0]!.action).toBe("settings.updated");
    expect(settingsAudits[0]!.afterState).toMatchObject({ rounding_rule: "round_half_even" });

    // A second, rejected attempt (stale base_updated_at) must not write a second entry.
    await expect(
      settingsService.updateSettings(tenant.authUserId, tenant.tenantId, {
        client_operation_id: randomUUID(),
        base_updated_at: before.updatedAt.toISOString(),
        rounding_rule: "round_half_up",
      }),
    ).rejects.toMatchObject({ code: "SETTINGS_CONFLICT" });
    expect(
      await prisma.auditLog.findMany({ where: { entityType: "shop_settings", entityId: tenant.tenantId } }),
    ).toHaveLength(1);
  });
});
