import { randomUUID } from "node:crypto";
import type { PrismaClient } from "@prisma/client";

/**
 * Seeds one full, realistic row per real (built) tenant-owned table for a single tenant — the
 * fixture the cross-tenant isolation suite (Sprint 40, backlog.md M4 item 5) attacks from the
 * "other" tenant. Every row is created inside one transaction so `Tenant.createdBy`'s deferred FK
 * (checked at COMMIT, not per-statement — see schema.prisma's own Tenant model comment) resolves
 * correctly even though `Tenant` is inserted before the `User` row it references.
 */
export async function seedTenant(prisma: PrismaClient, label: string) {
  const ids = {
    tenantId: randomUUID(),
    storeId: randomUUID(),
    userId: randomUUID(),
    categoryId: randomUUID(),
    unitId: randomUUID(),
    productId: randomUUID(),
    customerId: randomUUID(),
    tradingDayId: randomUUID(),
    saleId: randomUUID(),
    saleLineItemId: randomUUID(),
    salePaymentId: randomUUID(),
    returnId: randomUUID(),
    returnLineItemId: randomUUID(),
    stockMovementId: randomUUID(),
    auditLogId: randomUUID(),
    invoiceSequenceId: randomUUID(),
    userStoreRoleId: randomUUID(),
    customerFieldConflictId: randomUUID(),
  };

  await prisma.$transaction(async (tx) => {
    await tx.tenant.create({ data: { id: ids.tenantId, name: `Tenant ${label}`, createdBy: ids.userId } });
    await tx.user.create({
      data: {
        id: ids.userId,
        tenantId: ids.tenantId,
        authUserId: randomUUID(),
        displayName: `Owner ${label}`,
        createdBy: ids.userId,
      },
    });
    await tx.store.create({
      data: { id: ids.storeId, tenantId: ids.tenantId, name: `Store ${label}`, createdBy: ids.userId },
    });
    await tx.userStoreRole.create({
      data: {
        id: ids.userStoreRoleId,
        tenantId: ids.tenantId,
        userId: ids.userId,
        storeId: ids.storeId,
        role: "owner",
        assignedBy: ids.userId,
      },
    });
    await tx.category.create({
      data: { id: ids.categoryId, tenantId: ids.tenantId, name: `Category ${label}`, createdBy: ids.userId },
    });
    await tx.unit.create({
      data: { id: ids.unitId, tenantId: ids.tenantId, name: `Unit ${label}`, symbol: label, createdBy: ids.userId },
    });
    await tx.product.create({
      data: {
        id: ids.productId,
        tenantId: ids.tenantId,
        categoryId: ids.categoryId,
        unitId: ids.unitId,
        name: `Product ${label}`,
        priceMinorUnits: 1000n,
        createdBy: ids.userId,
      },
    });
    await tx.customer.create({
      data: {
        id: ids.customerId,
        tenantId: ids.tenantId,
        name: `Customer ${label}`,
        phone: `9${label.padStart(9, "0")}`,
        createdBy: ids.userId,
      },
    });
    await tx.tradingDay.create({
      data: {
        id: ids.tradingDayId,
        tenantId: ids.tenantId,
        storeId: ids.storeId,
        status: "open",
        startingFloatMinorUnits: 0n,
        createdBy: ids.userId,
      },
    });
    await tx.sale.create({
      data: {
        id: ids.saleId,
        tenantId: ids.tenantId,
        storeId: ids.storeId,
        tradingDayId: ids.tradingDayId,
        customerId: ids.customerId,
        status: "completed",
        provisionalInvoiceNumber: `PROV-${label}`,
        subtotalMinorUnits: 1000n,
        grandTotalMinorUnits: 1000n,
        completedAt: new Date(),
        createdBy: ids.userId,
      },
    });
    await tx.saleLineItem.create({
      data: {
        id: ids.saleLineItemId,
        saleId: ids.saleId,
        productId: ids.productId,
        quantity: 1,
        unitPriceMinorUnits: 1000n,
        lineTotalMinorUnits: 1000n,
      },
    });
    await tx.salePayment.create({
      data: { id: ids.salePaymentId, saleId: ids.saleId, method: "cash", amountMinorUnits: 1000n },
    });
    await tx.stockMovement.create({
      data: {
        id: ids.stockMovementId,
        tenantId: ids.tenantId,
        storeId: ids.storeId,
        productId: ids.productId,
        quantityDelta: 10,
        movementType: "opening",
        createdBy: ids.userId,
      },
    });
    await tx.return.create({
      data: {
        id: ids.returnId,
        tenantId: ids.tenantId,
        storeId: ids.storeId,
        originalSaleId: ids.saleId,
        status: "completed",
        refundTotalMinorUnits: 100n,
        completedAt: new Date(),
        createdBy: ids.userId,
      },
    });
    await tx.returnLineItem.create({
      data: {
        id: ids.returnLineItemId,
        returnId: ids.returnId,
        originalSaleLineItemId: ids.saleLineItemId,
        quantity: 1,
        refundAmountMinorUnits: 100n,
      },
    });
    await tx.auditLog.create({
      data: {
        id: ids.auditLogId,
        tenantId: ids.tenantId,
        storeId: ids.storeId,
        actorUserId: ids.userId,
        action: "sale.completed",
        entityType: "sale",
        entityId: ids.saleId,
      },
    });
    await tx.invoiceSequence.create({
      data: { id: ids.invoiceSequenceId, tenantId: ids.tenantId, financialYear: "2026", nextValue: 1n },
    });
    await tx.shopSettings.create({
      data: {
        tenantId: ids.tenantId,
        taxMode: "unregistered",
        pricingMode: "inclusive",
        roundingRule: "round_half_up",
        discountAutoApprovalThresholdMinorUnits: 50000n,
        returnAutoApprovalThresholdMinorUnits: 100000n,
        createdBy: ids.userId,
      },
    });
    await tx.customerFieldConflict.create({
      data: {
        id: ids.customerFieldConflictId,
        tenantId: ids.tenantId,
        customerId: ids.customerId,
        field: "phone",
        currentSetBy: ids.userId,
        attemptedSetBy: ids.userId,
      },
    });
  });

  return ids;
}

export type SeededTenant = Awaited<ReturnType<typeof seedTenant>>;
