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

const input: CreateProductRequest = {
  id: "44444444-4444-4444-8444-444444444444",
  name: "Test Product",
  price_minor_units: 2800,
};

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
      created_at: "2026-08-01T00:00:00.000Z",
      updated_at: "2026-08-01T00:00:00.000Z",
    });
  });

  it("converts the stored BigInt price back to a plain number in the response", async () => {
    vi.mocked(repository.createProduct).mockResolvedValue({
      id: input.id,
      name: input.name,
      priceMinorUnits: BigInt(0),
      createdAt: new Date(),
      updatedAt: new Date(),
    } as never);

    const result = await createProduct(authUserId, tenantId, { ...input, price_minor_units: 0 });

    expect(result.price_minor_units).toBe(0);
    expect(typeof result.price_minor_units).toBe("number");
  });
});
