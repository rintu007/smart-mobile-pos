import { Prisma } from "@prisma/client";
import * as repository from "./repository";
import { ApiError } from "@/core/errors/api-error";
import type { OpenTradingDayRequest, CloseTradingDayRequest } from "./schema";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

const UNIQUE_CONSTRAINT_VIOLATION = "P2002";

// Prisma resolves a raw-SQL partial unique index's violation back to its column list, not the
// index name itself — `meta.target: ["tenant_id", "store_id"]`, not
// "trading_days_one_open_per_store" — found live, not by inspection (the first attempt compared
// against the index name and silently fell through to a raw 500 instead of translating it).
function isOneOpenPerStoreViolation(error: Prisma.PrismaClientKnownRequestError): boolean {
  const target = error.meta?.target;
  return (
    Array.isArray(target) && target.includes("tenant_id") && target.includes("store_id")
  );
}

function formatTradingDay(tradingDay: {
  id: string;
  status: string;
  startingFloatMinorUnits: bigint;
  countedCashMinorUnits: bigint | null;
  expectedCashMinorUnits: bigint | null;
  varianceMinorUnits: bigint | null;
  closedAt: Date | null;
  reopenedAt: Date | null;
  createdAt: Date;
}) {
  return {
    id: tradingDay.id,
    status: tradingDay.status,
    starting_float_minor_units: Number(tradingDay.startingFloatMinorUnits),
    counted_cash_minor_units:
      tradingDay.countedCashMinorUnits === null ? null : Number(tradingDay.countedCashMinorUnits),
    expected_cash_minor_units:
      tradingDay.expectedCashMinorUnits === null
        ? null
        : Number(tradingDay.expectedCashMinorUnits),
    variance_minor_units:
      tradingDay.varianceMinorUnits === null ? null : Number(tradingDay.varianceMinorUnits),
    closed_at: tradingDay.closedAt?.toISOString() ?? null,
    reopened_at: tradingDay.reopenedAt?.toISOString() ?? null,
    created_at: tradingDay.createdAt.toISOString(),
  };
}

// docs/modules/trading-day/specification.md #4-api-contract — GET /trading-days/current. "No open
// day" is a normal, expected state, not an error — a shaped 200, never a 404.
export async function getCurrentTradingDay(tenantId: string, storeId: string) {
  const tradingDay = await repository.findOpenTradingDay(tenantId, storeId);
  return { trading_day: tradingDay ? formatTradingDay(tradingDay) : null };
}

/**
 * docs/modules/trading-day/specification.md #4-api-contract — POST /trading-days/open.
 *
 * Idempotent replay checked before any write, the same "check existing by id, return early"
 * pattern pos/service.ts's own createSale already established — a retry of the same `id` must
 * never risk a spurious TRADING_DAY_ALREADY_OPEN.
 */
export async function openTradingDay(
  tenantId: string,
  storeId: string,
  createdBy: string,
  input: OpenTradingDayRequest,
) {
  const existing = await repository.findById(tenantId, input.id);
  if (existing) {
    return formatTradingDay(existing);
  }

  try {
    const tradingDay = await repository.openTradingDay({
      id: input.id,
      tenantId,
      storeId,
      startingFloatMinorUnits: BigInt(input.starting_float_minor_units),
      createdBy,
    });
    return formatTradingDay(tradingDay);
  } catch (error) {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === UNIQUE_CONSTRAINT_VIOLATION &&
      isOneOpenPerStoreViolation(error)
    ) {
      throw new ApiError(
        409,
        "TRADING_DAY_ALREADY_OPEN",
        "A trading day is already open at this store.",
      );
    }
    throw error;
  }
}

/**
 * docs/modules/trading-day/specification.md #4-api-contract — POST /trading-days/{id}/close.
 * Closing an already-closed day is an idempotent no-op — the submitted counted_cash_minor_units on
 * a replay is not re-applied (§2).
 */
export async function closeTradingDay(
  tenantId: string,
  storeId: string,
  actorUserId: string,
  id: string,
  input: CloseTradingDayRequest,
) {
  const existing = await repository.findById(tenantId, id);
  if (!existing) {
    throw new ApiError(404, "NOT_FOUND", "No trading day with this id exists.");
  }
  if (existing.status === "closed") {
    return formatTradingDay(existing);
  }

  const tradingDay = await repository.closeTradingDay({
    tradingDayId: id,
    tenantId,
    storeId,
    countedCashMinorUnits: BigInt(input.counted_cash_minor_units),
    actorUserId,
  });
  return formatTradingDay(tradingDay);
}

/**
 * docs/modules/trading-day/specification.md #4-api-contract — POST /trading-days/{id}/reopen,
 * Manager/Owner only (enforced by the Route Handler's own requirePermission call, not here).
 * Reopening an already-open day (the same day) is an idempotent no-op; reopening while a
 * *different* day is open at the store hits the same partial unique index as open() (§2).
 */
export async function reopenTradingDay(tenantId: string, storeId: string, actorUserId: string, id: string) {
  const existing = await repository.findById(tenantId, id);
  if (!existing) {
    throw new ApiError(404, "NOT_FOUND", "No trading day with this id exists.");
  }
  if (existing.status === "open") {
    return formatTradingDay(existing);
  }
  if (existing.status !== "closed") {
    throw new ApiError(409, "TRADING_DAY_NOT_CLOSED", "This trading day is not closed.");
  }

  try {
    const tradingDay = await repository.reopenTradingDay({
      tradingDayId: id,
      tenantId,
      storeId,
      actorUserId,
    });
    return formatTradingDay(tradingDay);
  } catch (error) {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === UNIQUE_CONSTRAINT_VIOLATION &&
      isOneOpenPerStoreViolation(error)
    ) {
      throw new ApiError(
        409,
        "TRADING_DAY_ALREADY_OPEN",
        "A different trading day is already open at this store.",
      );
    }
    throw error;
  }
}
