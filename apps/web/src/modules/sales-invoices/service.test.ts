import { describe, expect, it, vi, beforeEach } from "vitest";
import * as repository from "./repository";
import { getSaleDetail, listSales, lookupSale } from "./service";

vi.mock("./repository");

const tenantId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";
const saleId = "66666666-6666-4666-8666-666666666666";

const sale = (overrides: Partial<Record<string, unknown>> = {}) => ({
  id: saleId,
  status: "completed",
  provisionalInvoiceNumber: "DEV042-2026-000001",
  canonicalInvoiceNumber: BigInt(1),
  financialYear: "2026",
  subtotalMinorUnits: BigInt(2800),
  grandTotalMinorUnits: BigInt(2800),
  completedAt: new Date("2026-08-14T00:00:00Z"),
  createdBy: userId,
  lineItems: [],
  payments: [],
  ...overrides,
});

describe("getSaleDetail", () => {
  beforeEach(() => vi.resetAllMocks());

  it("returns the formatted sale", async () => {
    vi.mocked(repository.findSaleWithDetails).mockResolvedValue(sale() as never);

    const result = await getSaleDetail(tenantId, saleId);

    expect(repository.findSaleWithDetails).toHaveBeenCalledWith(tenantId, saleId);
    expect(result.canonical_invoice_number).toBe(1);
  });

  it("rejects an unknown sale with NOT_FOUND", async () => {
    vi.mocked(repository.findSaleWithDetails).mockResolvedValue(null as never);

    await expect(getSaleDetail(tenantId, saleId)).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
  });
});

describe("lookupSale", () => {
  beforeEach(() => vi.resetAllMocks());

  it("looks up by provisional_invoice_number", async () => {
    vi.mocked(repository.findSaleByInvoiceNumber).mockResolvedValue(sale() as never);

    await lookupSale(tenantId, { provisional_invoice_number: "DEV042-2026-000001" });

    expect(repository.findSaleByInvoiceNumber).toHaveBeenCalledWith(tenantId, {
      provisionalInvoiceNumber: "DEV042-2026-000001",
      canonicalInvoiceNumber: undefined,
    });
  });

  it("looks up by canonical_invoice_number, converting to BigInt", async () => {
    vi.mocked(repository.findSaleByInvoiceNumber).mockResolvedValue(sale() as never);

    await lookupSale(tenantId, { canonical_invoice_number: 1 });

    expect(repository.findSaleByInvoiceNumber).toHaveBeenCalledWith(tenantId, {
      provisionalInvoiceNumber: undefined,
      canonicalInvoiceNumber: BigInt(1),
    });
  });

  it("rejects no match with NOT_FOUND", async () => {
    vi.mocked(repository.findSaleByInvoiceNumber).mockResolvedValue(null as never);

    await expect(lookupSale(tenantId, { canonical_invoice_number: 999 })).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
  });
});

describe("listSales", () => {
  beforeEach(() => vi.resetAllMocks());

  it("passes createdBy for a cashier (own sales only)", async () => {
    vi.mocked(repository.listSales).mockResolvedValue([] as never);

    await listSales(tenantId, "cashier", userId, { limit: 50 });

    expect(repository.listSales).toHaveBeenCalledWith(
      tenantId,
      { createdBy: userId, dateFrom: undefined, dateTo: undefined },
      null,
      50,
    );
  });

  it("passes no createdBy filter for manager/owner (store-wide)", async () => {
    vi.mocked(repository.listSales).mockResolvedValue([] as never);

    await listSales(tenantId, "owner", userId, { limit: 50 });

    expect(repository.listSales).toHaveBeenCalledWith(
      tenantId,
      { createdBy: undefined, dateFrom: undefined, dateTo: undefined },
      null,
      50,
    );
  });

  it("passes date_from/date_to filters through as Date objects", async () => {
    vi.mocked(repository.listSales).mockResolvedValue([] as never);

    await listSales(tenantId, "owner", userId, {
      limit: 50,
      date_from: "2026-08-01T00:00:00.000Z",
      date_to: "2026-08-14T00:00:00.000Z",
    });

    expect(repository.listSales).toHaveBeenCalledWith(
      tenantId,
      {
        createdBy: undefined,
        dateFrom: new Date("2026-08-01T00:00:00.000Z"),
        dateTo: new Date("2026-08-14T00:00:00.000Z"),
      },
      null,
      50,
    );
  });

  it("returns a non-null next_cursor when more rows exist beyond the requested limit", async () => {
    const rows = [
      sale({ id: "s1", completedAt: new Date("2026-08-01T00:00:00Z") }),
      sale({ id: "s2", completedAt: new Date("2026-08-02T00:00:00Z") }),
      sale({ id: "s3", completedAt: new Date("2026-08-03T00:00:00Z") }),
    ];
    vi.mocked(repository.listSales).mockResolvedValue(rows as never);

    const result = await listSales(tenantId, "owner", userId, { limit: 2 });

    expect(result.data).toHaveLength(2);
    expect(result.next_cursor).not.toBeNull();
  });

  it("returns a null next_cursor when the page is partial (end of data)", async () => {
    vi.mocked(repository.listSales).mockResolvedValue([sale()] as never);

    const result = await listSales(tenantId, "owner", userId, { limit: 50 });

    expect(result.next_cursor).toBeNull();
  });

  it("rejects a malformed cursor with VALIDATION_FAILED rather than crashing", async () => {
    await expect(
      listSales(tenantId, "owner", userId, { cursor: "not-a-real-cursor!!", limit: 50 }),
    ).rejects.toMatchObject({ status: 422, code: "VALIDATION_FAILED" });
  });
});
