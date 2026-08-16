import { describe, expect, it, vi, beforeEach } from "vitest";
import * as repository from "./repository";
import { getSettings, updateSettings } from "./service";
import type { UpdateSettingsRequest } from "./schema";

vi.mock("./repository");

const tenantId = "22222222-2222-4222-8222-222222222222";
const updatedAt = new Date("2026-08-14T00:00:00.000Z");

const row = (overrides: Partial<Record<string, unknown>> = {}) => ({
  tenantId,
  taxMode: "unregistered",
  taxRateBasisPoints: 0,
  pricingMode: "inclusive",
  roundingRule: "round_half_up",
  currencyCode: "INR",
  discountAutoApprovalThresholdMinorUnits: BigInt(50000),
  returnAutoApprovalThresholdMinorUnits: BigInt(100000),
  lowStockThresholdQuantity: 5,
  printerConfig: null,
  receiptTemplateConfig: null,
  createdAt: updatedAt,
  updatedAt,
  createdBy: "11111111-1111-4111-8111-111111111111",
  ...overrides,
});

describe("getSettings", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("includes both auto-approval thresholds for a Manager", async () => {
    vi.mocked(repository.findSettings).mockResolvedValue(row() as never);

    const result = await getSettings(tenantId, "manager");

    expect(result).toMatchObject({
      discount_auto_approval_threshold_minor_units: 50000,
      return_auto_approval_threshold_minor_units: 100000,
    });
  });

  it("includes both auto-approval thresholds for an Owner", async () => {
    vi.mocked(repository.findSettings).mockResolvedValue(row() as never);

    const result = await getSettings(tenantId, "owner");

    expect(result).toMatchObject({
      discount_auto_approval_threshold_minor_units: 50000,
      return_auto_approval_threshold_minor_units: 100000,
    });
  });

  it("omits both auto-approval thresholds entirely for a Cashier", async () => {
    vi.mocked(repository.findSettings).mockResolvedValue(row() as never);

    const result = await getSettings(tenantId, "cashier");

    expect(result).not.toHaveProperty("discount_auto_approval_threshold_minor_units");
    expect(result).not.toHaveProperty("return_auto_approval_threshold_minor_units");
  });

  it("throws NOT_FOUND when no settings row exists for the tenant", async () => {
    vi.mocked(repository.findSettings).mockResolvedValue(null);

    await expect(getSettings(tenantId, "owner")).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
  });

  it("includes low_stock_threshold_quantity for every role, including Cashier (Sprint 37)", async () => {
    vi.mocked(repository.findSettings).mockResolvedValue(row({ lowStockThresholdQuantity: 8 }) as never);

    const cashierResult = await getSettings(tenantId, "cashier");
    const ownerResult = await getSettings(tenantId, "owner");

    expect(cashierResult).toMatchObject({ low_stock_threshold_quantity: 8 });
    expect(ownerResult).toMatchObject({ low_stock_threshold_quantity: 8 });
  });
});

describe("updateSettings", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  const baseInput: UpdateSettingsRequest = {
    client_operation_id: "44444444-4444-4444-8444-444444444444",
    base_updated_at: updatedAt.toISOString(),
  };

  it("rejects a stale base_updated_at with SETTINGS_CONFLICT", async () => {
    vi.mocked(repository.findSettings).mockResolvedValue(row() as never);

    await expect(
      updateSettings(tenantId, { ...baseInput, base_updated_at: "2020-01-01T00:00:00.000Z" }),
    ).rejects.toMatchObject({ status: 409, code: "SETTINGS_CONFLICT" });
    expect(repository.updateSettingsIfUnchanged).not.toHaveBeenCalled();
  });

  it("rejects a nonzero tax rate when the resulting tax_mode is not 'standard' (existing mode)", async () => {
    vi.mocked(repository.findSettings).mockResolvedValue(row({ taxMode: "unregistered" }) as never);

    await expect(
      updateSettings(tenantId, { ...baseInput, tax_rate_basis_points: 500 }),
    ).rejects.toMatchObject({ status: 422, code: "TAX_RATE_REQUIRES_STANDARD_MODE" });
  });

  it("rejects a request that sets tax_mode away from standard while a nonzero rate remains", async () => {
    vi.mocked(
      repository.findSettings,
    ).mockResolvedValue(row({ taxMode: "standard", taxRateBasisPoints: 500 }) as never);

    await expect(
      updateSettings(tenantId, { ...baseInput, tax_mode: "unregistered" }),
    ).rejects.toMatchObject({ status: 422, code: "TAX_RATE_REQUIRES_STANDARD_MODE" });
  });

  it("accepts a nonzero tax rate when tax_mode is (or becomes) standard", async () => {
    vi.mocked(repository.findSettings)
      .mockResolvedValueOnce(row({ taxMode: "unregistered", taxRateBasisPoints: 0 }) as never)
      .mockResolvedValueOnce(row({ taxMode: "standard", taxRateBasisPoints: 500 }) as never);
    vi.mocked(repository.updateSettingsIfUnchanged).mockResolvedValue(true);

    const result = await updateSettings(tenantId, {
      ...baseInput,
      tax_mode: "standard",
      tax_rate_basis_points: 500,
    });

    expect(repository.updateSettingsIfUnchanged).toHaveBeenCalledWith(
      tenantId,
      updatedAt,
      expect.objectContaining({ taxMode: "standard", taxRateBasisPoints: 500 }),
    );
    expect(result).toMatchObject({ tax_mode: "standard", tax_rate_basis_points: 500 });
  });

  it("only writes the fields present in the request, leaving the rest untouched", async () => {
    vi.mocked(repository.findSettings)
      .mockResolvedValueOnce(row() as never)
      .mockResolvedValueOnce(row({ roundingRule: "round_half_even" }) as never);
    vi.mocked(repository.updateSettingsIfUnchanged).mockResolvedValue(true);

    await updateSettings(tenantId, { ...baseInput, rounding_rule: "round_half_even" });

    expect(repository.updateSettingsIfUnchanged).toHaveBeenCalledWith(
      tenantId,
      updatedAt,
      { roundingRule: "round_half_even" },
    );
  });

  it("surfaces SETTINGS_CONFLICT when a concurrent write wins the race at the database level", async () => {
    vi.mocked(repository.findSettings).mockResolvedValue(row() as never);
    vi.mocked(repository.updateSettingsIfUnchanged).mockResolvedValue(false);

    await expect(
      updateSettings(tenantId, { ...baseInput, rounding_rule: "round_half_even" }),
    ).rejects.toMatchObject({ status: 409, code: "SETTINGS_CONFLICT" });
  });

  it("throws NOT_FOUND when no settings row exists for the tenant", async () => {
    vi.mocked(repository.findSettings).mockResolvedValue(null);

    await expect(updateSettings(tenantId, baseInput)).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
  });

  it("writes low_stock_threshold_quantity alone, leaving other fields untouched (Sprint 37)", async () => {
    vi.mocked(repository.findSettings)
      .mockResolvedValueOnce(row() as never)
      .mockResolvedValueOnce(row({ lowStockThresholdQuantity: 10 }) as never);
    vi.mocked(repository.updateSettingsIfUnchanged).mockResolvedValue(true);

    const result = await updateSettings(tenantId, { ...baseInput, low_stock_threshold_quantity: 10 });

    expect(repository.updateSettingsIfUnchanged).toHaveBeenCalledWith(
      tenantId,
      updatedAt,
      { lowStockThresholdQuantity: 10 },
    );
    expect(result).toMatchObject({ low_stock_threshold_quantity: 10 });
  });
});
