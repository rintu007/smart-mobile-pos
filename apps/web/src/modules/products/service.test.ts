import { Prisma } from "@prisma/client";
import { describe, expect, it, vi, beforeEach } from "vitest";
import * as identityService from "@/modules/identity/service";
import * as storesService from "@/modules/stores/service";
import * as repository from "./repository";
import { createProduct } from "./service";
import type { CreateProductRequest } from "./schema";

vi.mock("./repository");
vi.mock("@/modules/identity/service");
vi.mock("@/modules/stores/service");

const authUserId = "11111111-1111-4111-8111-111111111111";
const tenantId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";
const storeId = "55555555-5555-4555-8555-555555555555";
const categoryId = "66666666-6666-4666-8666-666666666666";
const unitId = "77777777-7777-4777-8777-777777777777";

const input: CreateProductRequest = {
  id: "44444444-4444-4444-8444-444444444444",
  name: "Test Product",
  price_minor_units: 2800,
};

function uniqueConstraintError(target: string[]) {
  return new Prisma.PrismaClientKnownRequestError("Unique constraint failed", {
    code: "P2002",
    clientVersion: "test",
    meta: { target },
  });
}

describe("createProduct", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(userId);
    vi.mocked(storesService.getPrimaryStoreId).mockResolvedValue(storeId);
  });

  it("resolves the internal user id and creates the product under it", async () => {
    const created = {
      id: input.id,
      name: input.name,
      priceMinorUnits: BigInt(input.price_minor_units),
      categoryId: null,
      unitId: null,
      sku: null,
      barcode: null,
      hsnSacCode: null,
      createdAt: new Date("2026-08-01T00:00:00Z"),
      updatedAt: new Date("2026-08-01T00:00:00Z"),
    };
    vi.mocked(repository.createProduct).mockResolvedValue(created as never);

    const result = await createProduct(authUserId, tenantId, input);

    expect(identityService.resolveUserId).toHaveBeenCalledWith(authUserId);
    expect(storesService.getPrimaryStoreId).toHaveBeenCalledWith(tenantId);
    expect(repository.createProduct).toHaveBeenCalledWith({
      ...input,
      tenantId,
      createdBy: userId,
      storeId,
    });
    expect(result).toEqual({
      id: input.id,
      name: input.name,
      price_minor_units: input.price_minor_units,
      category_id: null,
      unit_id: null,
      sku: null,
      barcode: null,
      hsn_sac_code: null,
      created_at: "2026-08-01T00:00:00.000Z",
      updated_at: "2026-08-01T00:00:00.000Z",
    });
  });

  it("converts the stored BigInt price back to a plain number in the response", async () => {
    vi.mocked(repository.createProduct).mockResolvedValue({
      id: input.id,
      name: input.name,
      priceMinorUnits: BigInt(0),
      categoryId: null,
      unitId: null,
      sku: null,
      barcode: null,
      hsnSacCode: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    } as never);

    const result = await createProduct(authUserId, tenantId, { ...input, price_minor_units: 0 });

    expect(result.price_minor_units).toBe(0);
    expect(typeof result.price_minor_units).toBe("number");
  });

  it("accepts a category_id/unit_id that exist under the same tenant and passes them through", async () => {
    vi.mocked(repository.findCategoryById).mockResolvedValue({ id: categoryId } as never);
    vi.mocked(repository.findUnitById).mockResolvedValue({ id: unitId } as never);
    vi.mocked(repository.createProduct).mockResolvedValue({
      id: input.id,
      name: input.name,
      priceMinorUnits: BigInt(input.price_minor_units),
      categoryId,
      unitId,
      sku: "SKU-1",
      barcode: "8901234567890",
      hsnSacCode: "0401",
      createdAt: new Date(),
      updatedAt: new Date(),
    } as never);

    const result = await createProduct(authUserId, tenantId, {
      ...input,
      category_id: categoryId,
      unit_id: unitId,
      sku: "SKU-1",
      barcode: "8901234567890",
      hsn_sac_code: "0401",
    });

    expect(repository.findCategoryById).toHaveBeenCalledWith(tenantId, categoryId);
    expect(repository.findUnitById).toHaveBeenCalledWith(tenantId, unitId);
    expect(result.category_id).toBe(categoryId);
    expect(result.unit_id).toBe(unitId);
    expect(result.sku).toBe("SKU-1");
    expect(result.barcode).toBe("8901234567890");
    expect(result.hsn_sac_code).toBe("0401");
  });

  it("rejects a category_id that doesn't exist under this tenant with NOT_FOUND", async () => {
    vi.mocked(repository.findCategoryById).mockResolvedValue(null as never);

    await expect(
      createProduct(authUserId, tenantId, { ...input, category_id: categoryId }),
    ).rejects.toMatchObject({ status: 404, code: "NOT_FOUND" });
    expect(repository.createProduct).not.toHaveBeenCalled();
  });

  it("rejects a unit_id that doesn't exist under this tenant with NOT_FOUND", async () => {
    vi.mocked(repository.findUnitById).mockResolvedValue(null as never);

    await expect(
      createProduct(authUserId, tenantId, { ...input, unit_id: unitId }),
    ).rejects.toMatchObject({ status: 404, code: "NOT_FOUND" });
    expect(repository.createProduct).not.toHaveBeenCalled();
  });

  it("translates a barcode unique-constraint violation into BARCODE_ALREADY_ASSIGNED", async () => {
    vi.mocked(repository.createProduct).mockRejectedValue(uniqueConstraintError(["tenant_id", "barcode"]));

    await expect(
      createProduct(authUserId, tenantId, { ...input, barcode: "8901234567890" }),
    ).rejects.toMatchObject({ status: 409, code: "BARCODE_ALREADY_ASSIGNED" });
  });

  it("translates a sku unique-constraint violation into SKU_ALREADY_ASSIGNED", async () => {
    vi.mocked(repository.createProduct).mockRejectedValue(uniqueConstraintError(["tenant_id", "sku"]));

    await expect(
      createProduct(authUserId, tenantId, { ...input, sku: "SKU-1" }),
    ).rejects.toMatchObject({ status: 409, code: "SKU_ALREADY_ASSIGNED" });
  });
});
