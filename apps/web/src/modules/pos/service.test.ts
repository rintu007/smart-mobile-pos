import { describe, expect, it, vi, beforeEach } from "vitest";
import * as identityService from "@/modules/identity/service";
import * as rolesService from "@/modules/roles/service";
import * as settingsService from "@/modules/settings/service";
import * as customersService from "@/modules/customers/service";
import * as repository from "./repository";
import { createSale } from "./service";
import type { CreateSaleRequest } from "./schema";

vi.mock("./repository");
vi.mock("@/modules/identity/service");
vi.mock("@/modules/roles/service");
vi.mock("@/modules/settings/service");
vi.mock("@/modules/customers/service");

const authUserId = "11111111-1111-4111-8111-111111111111";
const tenantId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";
const storeId = "44444444-4444-4444-8444-444444444444";
const productId = "55555555-5555-4555-8555-555555555555";
const saleId = "66666666-6666-4666-8666-666666666666";
const approverId = "99999999-9999-4999-8999-999999999999";

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

const createdSale = (overrides: Partial<Record<string, unknown>> = {}) => ({
  id: saleId,
  status: "completed",
  tradingDayId: null,
  customerId: null,
  provisionalInvoiceNumber: input.provisional_invoice_number,
  canonicalInvoiceNumber: BigInt(1),
  financialYear: "2026",
  subtotalMinorUnits: BigInt(5600),
  discountTotalMinorUnits: BigInt(0),
  taxTotalMinorUnits: BigInt(0),
  taxRegistrationTypeAtSale: "unregistered",
  grandTotalMinorUnits: BigInt(5600),
  completedAt: new Date("2026-08-01T00:00:00Z"),
  lineItems: [],
  payments: [],
  ...overrides,
});

// Matches Sprint 25's own onboarding defaults (unregistered, 0 rate, exclusive) so every
// pre-existing discount test's arithmetic is unaffected by tax's arrival.
const moneySettings = (overrides: Partial<Record<string, unknown>> = {}) => ({
  roundingRule: "round_half_up",
  discountAutoApprovalThresholdMinorUnits: BigInt(50000),
  returnAutoApprovalThresholdMinorUnits: BigInt(50000),
  taxMode: "unregistered",
  taxRateBasisPoints: 0,
  pricingMode: "exclusive",
  ...overrides,
});

describe("createSale", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(userId);
    vi.mocked(repository.findSaleById).mockResolvedValue(null);
    vi.mocked(repository.findProductsByIds).mockResolvedValue([product] as never);
    vi.mocked(settingsService.getMoneySettings).mockResolvedValue(moneySettings());
    vi.mocked(rolesService.resolveActiveRole).mockResolvedValue("cashier");
  });

  it("recomputes totals from the current product price and creates the sale", async () => {
    vi.mocked(repository.createSale).mockResolvedValue(
      createdSale({
        lineItems: [
          {
            id: "line-item-1",
            productId,
            quantity: 2,
            unitPriceMinorUnits: BigInt(2800),
            lineDiscountMinorUnits: BigInt(0),
            lineTotalMinorUnits: BigInt(5600),
          },
        ],
        payments: [{ method: "cash", amountMinorUnits: BigInt(5600) }],
      }) as never,
    );

    const result = await createSale(authUserId, tenantId, input);

    expect(repository.createSale).toHaveBeenCalledWith(
      expect.objectContaining({
        id: saleId,
        tenantId,
        storeId,
        createdBy: userId,
        subtotalMinorUnits: BigInt(5600),
        discountTotalMinorUnits: BigInt(0),
        grandTotalMinorUnits: BigInt(5600),
      }),
    );
    expect(result.grand_total_minor_units).toBe(5600);
    expect(result.discount_total_minor_units).toBe(0);
    expect(result.line_items).toHaveLength(1);
    // Sprint 34 (backlog.md M3 item 4) — the mobile Returns client needs each line item's own id.
    expect(result.line_items[0]?.id).toBe("line-item-1");
    expect(result.canonical_invoice_number).toBe(1);
    expect(result.financial_year).toBe("2026");
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
    vi.mocked(repository.findSaleById).mockResolvedValue(createdSale() as never);

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

  it("succeeds with no trading_day_id supplied at all -- the gate is deliberately not enforced yet", async () => {
    vi.mocked(repository.createSale).mockResolvedValue(createdSale() as never);

    await createSale(authUserId, tenantId, input);

    expect(repository.findOpenTradingDayById).not.toHaveBeenCalled();
  });

  it("links a supplied trading_day_id that resolves to an open day at this store", async () => {
    const tradingDayId = "77777777-7777-4777-8777-777777777777";
    vi.mocked(repository.findOpenTradingDayById).mockResolvedValue({ id: tradingDayId } as never);
    vi.mocked(repository.createSale).mockResolvedValue(createdSale({ tradingDayId }) as never);

    const result = await createSale(authUserId, tenantId, { ...input, trading_day_id: tradingDayId });

    expect(repository.findOpenTradingDayById).toHaveBeenCalledWith(tenantId, storeId, tradingDayId);
    expect(repository.createSale).toHaveBeenCalledWith(
      expect.objectContaining({ tradingDayId }),
    );
    expect(result.trading_day_id).toBe(tradingDayId);
  });

  it("rejects a supplied trading_day_id that doesn't resolve to an open day here with TRADING_DAY_NOT_OPEN", async () => {
    vi.mocked(repository.findOpenTradingDayById).mockResolvedValue(null);

    await expect(
      createSale(authUserId, tenantId, { ...input, trading_day_id: "88888888-8888-4888-8888-888888888888" }),
    ).rejects.toMatchObject({ status: 409, code: "TRADING_DAY_NOT_OPEN" });
    expect(repository.createSale).not.toHaveBeenCalled();
  });

  it("succeeds with no customer_id supplied at all -- customerExists is never called", async () => {
    vi.mocked(repository.createSale).mockResolvedValue(createdSale() as never);

    await createSale(authUserId, tenantId, input);

    expect(customersService.customerExists).not.toHaveBeenCalled();
  });

  it("links a supplied customer_id that resolves to a real customer under this tenant", async () => {
    const customerId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
    vi.mocked(customersService.customerExists).mockResolvedValue(true);
    vi.mocked(repository.createSale).mockResolvedValue(createdSale({ customerId }) as never);

    const result = await createSale(authUserId, tenantId, { ...input, customer_id: customerId });

    expect(customersService.customerExists).toHaveBeenCalledWith(tenantId, customerId);
    expect(repository.createSale).toHaveBeenCalledWith(expect.objectContaining({ customerId }));
    expect(result.customer_id).toBe(customerId);
  });

  it("rejects a customer_id that doesn't resolve under this tenant with NOT_FOUND", async () => {
    vi.mocked(customersService.customerExists).mockResolvedValue(false);

    await expect(
      createSale(authUserId, tenantId, {
        ...input,
        customer_id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      }),
    ).rejects.toMatchObject({ status: 404, code: "NOT_FOUND" });
    expect(repository.createSale).not.toHaveBeenCalled();
  });

  describe("discount", () => {
    it("computes a percent discount and rolls it into discount_total_minor_units", async () => {
      const discounted = {
        ...input,
        line_items: [
          {
            product_id: productId,
            quantity: 2,
            client_unit_price_minor_units: 2800,
            discount_percent_basis_points: 1000, // 10% of 5600 = 560
          },
        ],
        payments: [{ method: "cash" as const, amount_minor_units: 5040 }],
      };
      vi.mocked(repository.createSale).mockResolvedValue(createdSale() as never);

      await createSale(authUserId, tenantId, discounted);

      expect(repository.createSale).toHaveBeenCalledWith(
        expect.objectContaining({
          discountTotalMinorUnits: BigInt(560),
          subtotalMinorUnits: BigInt(5040),
          grandTotalMinorUnits: BigInt(5040),
          lineItems: [
            expect.objectContaining({
              lineDiscountMinorUnits: BigInt(560),
              lineTotalMinorUnits: BigInt(5040),
            }),
          ],
        }),
      );
    });

    it("computes a flat discount directly", async () => {
      const discounted = {
        ...input,
        line_items: [
          {
            product_id: productId,
            quantity: 2,
            client_unit_price_minor_units: 2800,
            discount_amount_minor_units: 600,
          },
        ],
        payments: [{ method: "cash" as const, amount_minor_units: 5000 }],
      };
      vi.mocked(repository.createSale).mockResolvedValue(createdSale() as never);

      await createSale(authUserId, tenantId, discounted);

      expect(repository.createSale).toHaveBeenCalledWith(
        expect.objectContaining({ discountTotalMinorUnits: BigInt(600) }),
      );
    });

    it("rejects a flat discount exceeding the line's own subtotal with VALIDATION_FAILED", async () => {
      const overDiscounted = {
        ...input,
        line_items: [
          {
            product_id: productId,
            quantity: 2,
            client_unit_price_minor_units: 2800,
            discount_amount_minor_units: 999999,
          },
        ],
      };

      await expect(createSale(authUserId, tenantId, overDiscounted)).rejects.toMatchObject({
        status: 422,
        code: "VALIDATION_FAILED",
      });
      expect(repository.createSale).not.toHaveBeenCalled();
    });

    it("applies an at-threshold discount with no approver needed", async () => {
      vi.mocked(settingsService.getMoneySettings).mockResolvedValue(
        moneySettings({ discountAutoApprovalThresholdMinorUnits: BigInt(560) }),
      );
      const atThreshold = {
        ...input,
        line_items: [
          {
            product_id: productId,
            quantity: 2,
            client_unit_price_minor_units: 2800,
            discount_amount_minor_units: 560,
          },
        ],
        payments: [{ method: "cash" as const, amount_minor_units: 5040 }],
      };
      vi.mocked(repository.createSale).mockResolvedValue(createdSale() as never);

      await createSale(authUserId, tenantId, atThreshold);

      expect(repository.createSale).toHaveBeenCalled();
      expect(rolesService.resolveActiveRole).not.toHaveBeenCalled();
    });

    it("rejects an over-threshold discount from a Cashier with no discount_approved_by", async () => {
      vi.mocked(settingsService.getMoneySettings).mockResolvedValue(
        moneySettings({ discountAutoApprovalThresholdMinorUnits: BigInt(100) }),
      );
      vi.mocked(rolesService.resolveActiveRole).mockResolvedValue("cashier");
      const overThreshold = {
        ...input,
        line_items: [
          {
            product_id: productId,
            quantity: 2,
            client_unit_price_minor_units: 2800,
            discount_amount_minor_units: 560,
          },
        ],
      };

      await expect(createSale(authUserId, tenantId, overThreshold)).rejects.toMatchObject({
        status: 409,
        code: "DISCOUNT_REQUIRES_APPROVAL",
      });
      expect(repository.createSale).not.toHaveBeenCalled();
    });

    it("allows an over-threshold discount when the caller's own session is Manager/Owner", async () => {
      vi.mocked(settingsService.getMoneySettings).mockResolvedValue(
        moneySettings({ discountAutoApprovalThresholdMinorUnits: BigInt(100) }),
      );
      vi.mocked(rolesService.resolveActiveRole).mockResolvedValue("manager");
      const overThreshold = {
        ...input,
        line_items: [
          {
            product_id: productId,
            quantity: 2,
            client_unit_price_minor_units: 2800,
            discount_amount_minor_units: 560,
          },
        ],
        payments: [{ method: "cash" as const, amount_minor_units: 5040 }],
      };
      vi.mocked(repository.createSale).mockResolvedValue(createdSale() as never);

      await createSale(authUserId, tenantId, overThreshold);

      expect(repository.createSale).toHaveBeenCalled();
    });

    it("allows an over-threshold discount when discount_approved_by resolves to an active Manager/Owner", async () => {
      vi.mocked(settingsService.getMoneySettings).mockResolvedValue(
        moneySettings({ discountAutoApprovalThresholdMinorUnits: BigInt(100) }),
      );
      vi.mocked(rolesService.resolveActiveRole).mockImplementation(async (_t, uid) =>
        uid === approverId ? "owner" : "cashier",
      );
      const overThreshold = {
        ...input,
        line_items: [
          {
            product_id: productId,
            quantity: 2,
            client_unit_price_minor_units: 2800,
            discount_amount_minor_units: 560,
          },
        ],
        payments: [{ method: "cash" as const, amount_minor_units: 5040 }],
        discount_approved_by: approverId,
      };
      vi.mocked(repository.createSale).mockResolvedValue(createdSale() as never);

      await createSale(authUserId, tenantId, overThreshold);

      expect(repository.createSale).toHaveBeenCalled();
    });

    it("rejects an over-threshold discount when discount_approved_by resolves to an insufficient role", async () => {
      vi.mocked(settingsService.getMoneySettings).mockResolvedValue(
        moneySettings({ discountAutoApprovalThresholdMinorUnits: BigInt(100) }),
      );
      vi.mocked(rolesService.resolveActiveRole).mockResolvedValue("cashier");
      const overThreshold = {
        ...input,
        line_items: [
          {
            product_id: productId,
            quantity: 2,
            client_unit_price_minor_units: 2800,
            discount_amount_minor_units: 560,
          },
        ],
        discount_approved_by: approverId,
      };

      await expect(createSale(authUserId, tenantId, overThreshold)).rejects.toMatchObject({
        status: 409,
        code: "DISCOUNT_REQUIRES_APPROVAL",
      });
      expect(repository.createSale).not.toHaveBeenCalled();
    });
  });

  describe("tax", () => {
    it("computes exclusive-pricing tax on the post-discount taxable value", async () => {
      // subtotal 5600, 10% discount (560) -> taxable 5040, 18% tax = ROUND(5040*0.18) = 907.2 -> 907
      vi.mocked(settingsService.getMoneySettings).mockResolvedValue(
        moneySettings({ taxMode: "standard", taxRateBasisPoints: 1800, pricingMode: "exclusive" }),
      );
      const discounted = {
        ...input,
        line_items: [
          {
            product_id: productId,
            quantity: 2,
            client_unit_price_minor_units: 2800,
            discount_percent_basis_points: 1000,
          },
        ],
        payments: [{ method: "cash" as const, amount_minor_units: 5947 }],
      };
      vi.mocked(repository.createSale).mockResolvedValue(createdSale() as never);

      await createSale(authUserId, tenantId, discounted);

      expect(repository.createSale).toHaveBeenCalledWith(
        expect.objectContaining({
          subtotalMinorUnits: BigInt(5040),
          taxTotalMinorUnits: BigInt(907),
          grandTotalMinorUnits: BigInt(5947),
          taxRegistrationTypeAtSale: "standard",
          lineItems: [
            expect.objectContaining({
              taxRateBasisPoints: 1800,
              lineTaxMinorUnits: BigInt(907),
              lineTotalMinorUnits: BigInt(5947),
            }),
          ],
        }),
      );
    });

    it("computes inclusive-pricing tax via the residual method, discount applied to the gross first", async () => {
      // unit price 2800 (tax-inclusive) x2 = 5600 gross, no discount, 5% tax:
      // taxable = ROUND(5600*10000/10500) = ROUND(5333.33) = 5333, tax = 5600-5333 = 267
      vi.mocked(settingsService.getMoneySettings).mockResolvedValue(
        moneySettings({ taxMode: "standard", taxRateBasisPoints: 500, pricingMode: "inclusive" }),
      );
      const withTax = { ...input, payments: [{ method: "cash" as const, amount_minor_units: 5600 }] };
      vi.mocked(repository.createSale).mockResolvedValue(createdSale() as never);

      await createSale(authUserId, tenantId, withTax);

      expect(repository.createSale).toHaveBeenCalledWith(
        expect.objectContaining({
          subtotalMinorUnits: BigInt(5333),
          taxTotalMinorUnits: BigInt(267),
          grandTotalMinorUnits: BigInt(5600),
          lineItems: [
            expect.objectContaining({ lineTaxMinorUnits: BigInt(267), lineTotalMinorUnits: BigInt(5600) }),
          ],
        }),
      );
    });

    it("computes zero tax under tax_mode unregistered even if a rate were somehow nonzero", async () => {
      vi.mocked(settingsService.getMoneySettings).mockResolvedValue(
        moneySettings({ taxMode: "unregistered", taxRateBasisPoints: 0, pricingMode: "exclusive" }),
      );
      vi.mocked(repository.createSale).mockResolvedValue(createdSale() as never);

      await createSale(authUserId, tenantId, input);

      expect(repository.createSale).toHaveBeenCalledWith(
        expect.objectContaining({
          taxTotalMinorUnits: BigInt(0),
          taxRegistrationTypeAtSale: "unregistered",
          subtotalMinorUnits: BigInt(5600),
          grandTotalMinorUnits: BigInt(5600),
        }),
      );
    });
  });

  describe("split payment", () => {
    it("accepts two payment entries (cash + card) summing exactly to the grand total", async () => {
      const split = {
        ...input,
        payments: [
          { method: "cash" as const, amount_minor_units: 3600 },
          { method: "card" as const, amount_minor_units: 2000 },
        ],
      };
      vi.mocked(repository.createSale).mockResolvedValue(createdSale() as never);

      await createSale(authUserId, tenantId, split);

      expect(repository.createSale).toHaveBeenCalledWith(
        expect.objectContaining({
          payments: [
            expect.objectContaining({ method: "cash", amountMinorUnits: BigInt(3600) }),
            expect.objectContaining({ method: "card", amountMinorUnits: BigInt(2000) }),
          ],
        }),
      );
    });

    it("accepts a three-way split (cash + card + other)", async () => {
      const split = {
        ...input,
        payments: [
          { method: "cash" as const, amount_minor_units: 2000 },
          { method: "card" as const, amount_minor_units: 2000 },
          { method: "other" as const, amount_minor_units: 1600 },
        ],
      };
      vi.mocked(repository.createSale).mockResolvedValue(createdSale() as never);

      await createSale(authUserId, tenantId, split);

      expect(repository.createSale).toHaveBeenCalled();
    });

    it("accepts a single card-only payment -- cash is not assumed present", async () => {
      const cardOnly = { ...input, payments: [{ method: "card" as const, amount_minor_units: 5600 }] };
      vi.mocked(repository.createSale).mockResolvedValue(createdSale() as never);

      await createSale(authUserId, tenantId, cardOnly);

      expect(repository.createSale).toHaveBeenCalledWith(
        expect.objectContaining({
          payments: [expect.objectContaining({ method: "card", amountMinorUnits: BigInt(5600) })],
        }),
      );
    });

    it("rejects a split whose entries don't sum to the grand total", async () => {
      const shortSplit = {
        ...input,
        payments: [
          { method: "cash" as const, amount_minor_units: 3000 },
          { method: "card" as const, amount_minor_units: 2000 },
        ],
      };

      await expect(createSale(authUserId, tenantId, shortSplit)).rejects.toMatchObject({
        status: 409,
        code: "PAYMENT_AMOUNT_MISMATCH",
      });
      expect(repository.createSale).not.toHaveBeenCalled();
    });
  });
});
