import { describe, expect, it, vi, beforeEach } from "vitest";
import * as identityService from "@/modules/identity/service";
import * as repository from "./repository";
import { createSale } from "./service";
import type { CreateSaleRequest } from "./schema";

vi.mock("./repository");
vi.mock("@/modules/identity/service");

const authUserId = "11111111-1111-4111-8111-111111111111";
const tenantId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";
const storeId = "44444444-4444-4444-8444-444444444444";
const productId = "55555555-5555-4555-8555-555555555555";
const saleId = "66666666-6666-4666-8666-666666666666";

const product = {
  id: productId,
  tenantId,
  name: "Test Product",
  priceMinorUnits: BigInt(2800),
  deactivatedAt: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  createdBy: userId,
};

const input: CreateSaleRequest = {
  id: saleId,
  store_id: storeId,
  provisional_invoice_number: "DEV-2026-000001",
  line_items: [{ product_id: productId, quantity: 2, client_unit_price_minor_units: 2800 }],
  payments: [{ method: "cash", amount_minor_units: 5600 }],
};

describe("createSale", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(userId);
    vi.mocked(repository.findSaleById).mockResolvedValue(null);
    vi.mocked(repository.findProductsByIds).mockResolvedValue([product] as never);
  });

  it("recomputes totals from the current product price and creates the sale", async () => {
    const created = {
      id: saleId,
      status: "completed",
      provisionalInvoiceNumber: input.provisional_invoice_number,
      subtotalMinorUnits: BigInt(5600),
      grandTotalMinorUnits: BigInt(5600),
      completedAt: new Date("2026-08-01T00:00:00Z"),
      lineItems: [
        {
          productId,
          quantity: 2,
          unitPriceMinorUnits: BigInt(2800),
          lineTotalMinorUnits: BigInt(5600),
        },
      ],
      payments: [{ method: "cash", amountMinorUnits: BigInt(5600) }],
    };
    vi.mocked(repository.createSale).mockResolvedValue(created as never);

    const result = await createSale(authUserId, tenantId, input);

    expect(repository.createSale).toHaveBeenCalledWith(
      expect.objectContaining({
        id: saleId,
        tenantId,
        storeId,
        createdBy: userId,
        grandTotalMinorUnits: BigInt(5600),
      }),
    );
    expect(result.grand_total_minor_units).toBe(5600);
    expect(result.line_items).toHaveLength(1);
  });

  it("rejects a stale client price with PRICE_MISMATCH and writes nothing", async () => {
    const staleInput = {
      ...input,
      line_items: [{ product_id: productId, quantity: 2, client_unit_price_minor_units: 2500 }],
    };

    await expect(createSale(authUserId, tenantId, staleInput)).rejects.toMatchObject({
      status: 409,
      code: "PRICE_MISMATCH",
    });
    expect(repository.createSale).not.toHaveBeenCalled();
  });

  it("rejects an unknown product with NOT_FOUND", async () => {
    vi.mocked(repository.findProductsByIds).mockResolvedValue([]);

    await expect(createSale(authUserId, tenantId, input)).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
    expect(repository.createSale).not.toHaveBeenCalled();
  });

  it("rejects a payment amount that doesn't equal the computed grand total", async () => {
    const underpaidInput = { ...input, payments: [{ method: "cash" as const, amount_minor_units: 1000 }] };

    await expect(createSale(authUserId, tenantId, underpaidInput)).rejects.toMatchObject({
      status: 409,
      code: "PAYMENT_AMOUNT_MISMATCH",
    });
    expect(repository.createSale).not.toHaveBeenCalled();
  });

  it("is idempotent: a retry with the same id returns the original sale without recomputing", async () => {
    const existing = {
      id: saleId,
      status: "completed",
      provisionalInvoiceNumber: input.provisional_invoice_number,
      subtotalMinorUnits: BigInt(5600),
      grandTotalMinorUnits: BigInt(5600),
      completedAt: new Date("2026-08-01T00:00:00Z"),
      lineItems: [],
      payments: [],
    };
    vi.mocked(repository.findSaleById).mockResolvedValue(existing as never);

    // Even a now-stale client price must not throw on replay.
    const staleReplay = {
      ...input,
      line_items: [{ product_id: productId, quantity: 2, client_unit_price_minor_units: 1 }],
    };

    const result = await createSale(authUserId, tenantId, staleReplay);

    expect(result.id).toBe(saleId);
    expect(repository.findProductsByIds).not.toHaveBeenCalled();
    expect(repository.createSale).not.toHaveBeenCalled();
  });
});
