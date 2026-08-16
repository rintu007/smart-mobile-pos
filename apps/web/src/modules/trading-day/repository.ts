import { randomUUID } from "node:crypto";
import { prisma } from "@/core/db/client";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

export function findOpenTradingDay(tenantId: string, storeId: string) {
  return prisma.tradingDay.findFirst({ where: { tenantId, storeId, status: "open" } });
}

export function findById(tenantId: string, id: string) {
  return prisma.tradingDay.findFirst({ where: { id, tenantId } });
}

export interface OpenTradingDayInput {
  id: string;
  tenantId: string;
  storeId: string;
  startingFloatMinorUnits: bigint;
  createdBy: string;
}

// docs/modules/trading-day/specification.md §2/§3 — the partial unique index
// (trading_days_one_open_per_store, this table's own migration) is the actual mechanism preventing
// two concurrent open days at the same store; service.ts translates its P2002 violation to
// TRADING_DAY_ALREADY_OPEN. One audit_log entry in the same transaction (audit-model.md §1).
export function openTradingDay(input: OpenTradingDayInput) {
  return prisma.$transaction(async (tx) => {
    const tradingDay = await tx.tradingDay.create({
      data: {
        id: input.id,
        tenantId: input.tenantId,
        storeId: input.storeId,
        status: "open",
        startingFloatMinorUnits: input.startingFloatMinorUnits,
        createdBy: input.createdBy,
      },
    });

    await tx.auditLog.create({
      data: {
        id: randomUUID(),
        tenantId: input.tenantId,
        storeId: input.storeId,
        actorUserId: input.createdBy,
        action: "trading_day.opened",
        entityType: "trading_day",
        entityId: tradingDay.id,
        afterState: {
          id: tradingDay.id,
          status: "open",
          starting_float_minor_units: Number(input.startingFloatMinorUnits),
        },
      },
    });

    return tradingDay;
  });
}

export interface CloseTradingDayInput {
  tradingDayId: string;
  tenantId: string;
  storeId: string;
  countedCashMinorUnits: bigint;
  actorUserId: string;
}

// docs/modules/trading-day/specification.md §2 — expected_cash_minor_units is always
// server-computed: the sum of cash sale_payments for completed sales linked to this trading day,
// never a client-submitted figure (api-principles.md §7).
export function closeTradingDay(input: CloseTradingDayInput) {
  return prisma.$transaction(async (tx) => {
    const cashPayments = await tx.salePayment.aggregate({
      where: {
        method: "cash",
        sale: { tradingDayId: input.tradingDayId, status: "completed" },
      },
      _sum: { amountMinorUnits: true },
    });
    const expectedCashMinorUnits = cashPayments._sum.amountMinorUnits ?? BigInt(0);
    const varianceMinorUnits = input.countedCashMinorUnits - expectedCashMinorUnits;

    const tradingDay = await tx.tradingDay.update({
      where: { id: input.tradingDayId },
      data: {
        status: "closed",
        countedCashMinorUnits: input.countedCashMinorUnits,
        expectedCashMinorUnits,
        varianceMinorUnits,
        closedAt: new Date(),
      },
    });

    await tx.auditLog.create({
      data: {
        id: randomUUID(),
        tenantId: input.tenantId,
        storeId: input.storeId,
        actorUserId: input.actorUserId,
        action: "trading_day.closed",
        entityType: "trading_day",
        entityId: tradingDay.id,
        afterState: {
          id: tradingDay.id,
          status: "closed",
          counted_cash_minor_units: Number(input.countedCashMinorUnits),
          expected_cash_minor_units: Number(expectedCashMinorUnits),
          variance_minor_units: Number(varianceMinorUnits),
        },
      },
    });

    return tradingDay;
  });
}

export interface ReopenTradingDayInput {
  tradingDayId: string;
  tenantId: string;
  storeId: string;
  actorUserId: string;
}

// docs/modules/trading-day/specification.md §2 — Manager/Owner only (checked by the Route
// Handler's own requirePermission call, not here); the partial unique index is this operation's
// own guard too, against a *different* day already being open at this store.
export function reopenTradingDay(input: ReopenTradingDayInput) {
  return prisma.$transaction(async (tx) => {
    const tradingDay = await tx.tradingDay.update({
      where: { id: input.tradingDayId },
      data: {
        status: "open",
        reopenedAt: new Date(),
        reopenedBy: input.actorUserId,
      },
    });

    await tx.auditLog.create({
      data: {
        id: randomUUID(),
        tenantId: input.tenantId,
        storeId: input.storeId,
        actorUserId: input.actorUserId,
        action: "trading_day.reopened",
        entityType: "trading_day",
        entityId: tradingDay.id,
        afterState: { id: tradingDay.id, status: "open" },
      },
    });

    return tradingDay;
  });
}
