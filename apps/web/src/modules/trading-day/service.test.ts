import { describe, expect, it, vi, beforeEach } from "vitest";
import { Prisma } from "@prisma/client";
import * as repository from "./repository";
import {
  getCurrentTradingDay,
  openTradingDay,
  closeTradingDay,
  reopenTradingDay,
} from "./service";
import type { OpenTradingDayRequest, CloseTradingDayRequest } from "./schema";

vi.mock("./repository");

const tenantId = "22222222-2222-4222-8222-222222222222";
const storeId = "44444444-4444-4444-8444-444444444444";
const userId = "33333333-3333-4333-8333-333333333333";
const tradingDayId = "55555555-5555-4555-8555-555555555555";

// meta.target is the column-name array ["tenant_id", "store_id"] for this hand-edited partial
// unique index, not the index's own name -- found live (service.ts's own comment), matched here
// so this mock actually exercises the real check rather than a shape Prisma never produces.
function uniqueConstraintError() {
  return new Prisma.PrismaClientKnownRequestError("Unique constraint failed", {
    code: "P2002",
    clientVersion: "test",
    meta: { target: ["tenant_id", "store_id"] },
  });
}

const row = (overrides: Partial<Record<string, unknown>> = {}) => ({
  id: tradingDayId,
  tenantId,
  storeId,
  status: "open",
  startingFloatMinorUnits: BigInt(0),
  countedCashMinorUnits: null,
  expectedCashMinorUnits: null,
  varianceMinorUnits: null,
  closedAt: null,
  reopenedAt: null,
  reopenedBy: null,
  createdAt: new Date("2026-08-14T00:00:00.000Z"),
  createdBy: userId,
  ...overrides,
});

describe("getCurrentTradingDay", () => {
  beforeEach(() => vi.resetAllMocks());

  it("returns null when no day is open at this store", async () => {
    vi.mocked(repository.findOpenTradingDay).mockResolvedValue(null);

    const result = await getCurrentTradingDay(tenantId, storeId);

    expect(result).toEqual({ trading_day: null });
  });

  it("returns the open day's shape when one exists", async () => {
    vi.mocked(repository.findOpenTradingDay).mockResolvedValue(row() as never);

    const result = await getCurrentTradingDay(tenantId, storeId);

    expect(result.trading_day).toMatchObject({ id: tradingDayId, status: "open" });
  });
});

describe("openTradingDay", () => {
  beforeEach(() => vi.resetAllMocks());

  const input: OpenTradingDayRequest = {
    id: tradingDayId,
    starting_float_minor_units: 1000,
  };

  it("is idempotent: a retry with the same id returns the original without writing again", async () => {
    vi.mocked(repository.findById).mockResolvedValue(row() as never);

    const result = await openTradingDay(tenantId, storeId, userId, input);

    expect(repository.openTradingDay).not.toHaveBeenCalled();
    expect(result.id).toBe(tradingDayId);
  });

  it("creates a new open day when none exists yet", async () => {
    vi.mocked(repository.findById).mockResolvedValue(null);
    vi.mocked(repository.openTradingDay).mockResolvedValue(row() as never);

    const result = await openTradingDay(tenantId, storeId, userId, input);

    expect(repository.openTradingDay).toHaveBeenCalledWith({
      id: tradingDayId,
      tenantId,
      storeId,
      startingFloatMinorUnits: BigInt(1000),
      createdBy: userId,
    });
    expect(result.status).toBe("open");
  });

  it("translates the partial-unique-index violation to TRADING_DAY_ALREADY_OPEN", async () => {
    vi.mocked(repository.findById).mockResolvedValue(null);
    vi.mocked(repository.openTradingDay).mockRejectedValue(
      uniqueConstraintError(),
    );

    await expect(openTradingDay(tenantId, storeId, userId, input)).rejects.toMatchObject({
      status: 409,
      code: "TRADING_DAY_ALREADY_OPEN",
    });
  });

  it("re-throws an unrelated database error unchanged", async () => {
    vi.mocked(repository.findById).mockResolvedValue(null);
    const dbError = new Error("connection reset");
    vi.mocked(repository.openTradingDay).mockRejectedValue(dbError);

    await expect(openTradingDay(tenantId, storeId, userId, input)).rejects.toBe(dbError);
  });
});

describe("closeTradingDay", () => {
  beforeEach(() => vi.resetAllMocks());

  const input: CloseTradingDayRequest = { counted_cash_minor_units: 5000 };

  it("throws NOT_FOUND when no such trading day exists under this tenant", async () => {
    vi.mocked(repository.findById).mockResolvedValue(null);

    await expect(
      closeTradingDay(tenantId, storeId, userId, tradingDayId, input),
    ).rejects.toMatchObject({ status: 404, code: "NOT_FOUND" });
  });

  it("is idempotent: closing an already-closed day returns the existing state without re-computing", async () => {
    vi.mocked(repository.findById).mockResolvedValue(
      row({ status: "closed", countedCashMinorUnits: BigInt(9999) }) as never,
    );

    const result = await closeTradingDay(tenantId, storeId, userId, tradingDayId, input);

    expect(repository.closeTradingDay).not.toHaveBeenCalled();
    expect(result.counted_cash_minor_units).toBe(9999);
  });

  it("closes an open day, delegating expected_cash computation to the repository", async () => {
    vi.mocked(repository.findById).mockResolvedValue(row({ status: "open" }) as never);
    vi.mocked(repository.closeTradingDay).mockResolvedValue(
      row({
        status: "closed",
        countedCashMinorUnits: BigInt(5000),
        expectedCashMinorUnits: BigInt(4800),
        varianceMinorUnits: BigInt(200),
      }) as never,
    );

    const result = await closeTradingDay(tenantId, storeId, userId, tradingDayId, input);

    expect(repository.closeTradingDay).toHaveBeenCalledWith({
      tradingDayId,
      tenantId,
      storeId,
      countedCashMinorUnits: BigInt(5000),
      actorUserId: userId,
    });
    expect(result.variance_minor_units).toBe(200);
  });
});

describe("reopenTradingDay", () => {
  beforeEach(() => vi.resetAllMocks());

  it("throws NOT_FOUND when no such trading day exists under this tenant", async () => {
    vi.mocked(repository.findById).mockResolvedValue(null);

    await expect(reopenTradingDay(tenantId, storeId, userId, tradingDayId)).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
  });

  it("is idempotent: reopening an already-open day returns the existing state", async () => {
    vi.mocked(repository.findById).mockResolvedValue(row({ status: "open" }) as never);

    const result = await reopenTradingDay(tenantId, storeId, userId, tradingDayId);

    expect(repository.reopenTradingDay).not.toHaveBeenCalled();
    expect(result.status).toBe("open");
  });

  it("reopens a closed day", async () => {
    vi.mocked(repository.findById).mockResolvedValue(row({ status: "closed" }) as never);
    vi.mocked(repository.reopenTradingDay).mockResolvedValue(
      row({ status: "open", reopenedAt: new Date("2026-08-14T01:00:00.000Z") }) as never,
    );

    const result = await reopenTradingDay(tenantId, storeId, userId, tradingDayId);

    expect(repository.reopenTradingDay).toHaveBeenCalledWith({
      tradingDayId,
      tenantId,
      storeId,
      actorUserId: userId,
    });
    expect(result.status).toBe("open");
  });

  it("translates the partial-unique-index violation to TRADING_DAY_ALREADY_OPEN when a different day is open", async () => {
    vi.mocked(repository.findById).mockResolvedValue(row({ status: "closed" }) as never);
    vi.mocked(repository.reopenTradingDay).mockRejectedValue(
      uniqueConstraintError(),
    );

    await expect(reopenTradingDay(tenantId, storeId, userId, tradingDayId)).rejects.toMatchObject({
      status: 409,
      code: "TRADING_DAY_ALREADY_OPEN",
    });
  });
});
