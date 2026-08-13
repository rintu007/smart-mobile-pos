import { describe, expect, it, vi, beforeEach } from "vitest";
import * as identityService from "@/modules/identity/service";
import * as storesService from "@/modules/stores/service";
import * as repository from "./repository";
import { createStockMovement, getStockBalance, listStockMovements } from "./service";
import type { CreateStockMovementRequest } from "./schema";

vi.mock("./repository");
vi.mock("@/modules/identity/service");
vi.mock("@/modules/stores/service");

const authUserId = "11111111-1111-4111-8111-111111111111";
const tenantId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";
const storeId = "55555555-5555-4555-8555-555555555555";
const productId = "66666666-6666-4666-8666-666666666666";

const adjustment: CreateStockMovementRequest = {
  id: "77777777-7777-4777-8777-777777777777",
  product_id: productId,
  quantity_delta: -2,
  movement_type: "adjustment",
  reason_code: "damage",
};

describe("createStockMovement", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(userId);
    vi.mocked(storesService.getPrimaryStoreId).mockResolvedValue(storeId);
    vi.mocked(repository.findProductById).mockResolvedValue({ id: productId } as never);
  });

  it("resolves store_id/created_by server-side and creates the adjustment", async () => {
    vi.mocked(repository.createStockMovement).mockResolvedValue({
      id: adjustment.id,
      productId,
      storeId,
      quantityDelta: -2,
      movementType: "adjustment",
      reasonCode: "damage",
      referenceType: null,
      referenceId: null,
      createdAt: new Date("2026-08-14T00:00:00Z"),
    } as never);

    const result = await createStockMovement(authUserId, tenantId, adjustment);

    expect(identityService.resolveUserId).toHaveBeenCalledWith(authUserId);
    expect(storesService.getPrimaryStoreId).toHaveBeenCalledWith(tenantId);
    expect(repository.createStockMovement).toHaveBeenCalledWith({
      ...adjustment,
      tenantId,
      storeId,
      createdBy: userId,
    });
    expect(result).toEqual({
      id: adjustment.id,
      product_id: productId,
      store_id: storeId,
      quantity_delta: -2,
      movement_type: "adjustment",
      reason_code: "damage",
      reference_type: null,
      reference_id: null,
      created_at: "2026-08-14T00:00:00.000Z",
    });
  });

  it("rejects movement_type: 'sale' with DIRECT_SALE_MOVEMENT_FORBIDDEN", async () => {
    await expect(
      createStockMovement(authUserId, tenantId, { ...adjustment, movement_type: "sale" }),
    ).rejects.toMatchObject({ status: 403, code: "DIRECT_SALE_MOVEMENT_FORBIDDEN" });
    expect(repository.createStockMovement).not.toHaveBeenCalled();
  });

  it("rejects movement_type: 'return' with DIRECT_SALE_MOVEMENT_FORBIDDEN", async () => {
    await expect(
      createStockMovement(authUserId, tenantId, { ...adjustment, movement_type: "return" }),
    ).rejects.toMatchObject({ status: 403, code: "DIRECT_SALE_MOVEMENT_FORBIDDEN" });
    expect(repository.createStockMovement).not.toHaveBeenCalled();
  });

  it("rejects an adjustment with no reason_code with ADJUSTMENT_REASON_REQUIRED", async () => {
    const { reason_code, ...withoutReason } = adjustment;
    void reason_code;

    await expect(
      createStockMovement(authUserId, tenantId, withoutReason as CreateStockMovementRequest),
    ).rejects.toMatchObject({ status: 422, code: "ADJUSTMENT_REASON_REQUIRED" });
    expect(repository.createStockMovement).not.toHaveBeenCalled();
  });

  it("rejects a product_id that doesn't exist under this tenant with NOT_FOUND", async () => {
    vi.mocked(repository.findProductById).mockResolvedValue(null as never);

    await expect(createStockMovement(authUserId, tenantId, adjustment)).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
    expect(repository.createStockMovement).not.toHaveBeenCalled();
  });
});

describe("listStockMovements", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  const movement = (id: string, createdAt: Date) => ({
    id,
    productId,
    storeId,
    quantityDelta: 1,
    movementType: "adjustment",
    reasonCode: "other",
    referenceType: null,
    referenceId: null,
    createdAt,
  });

  it("returns a non-null next_cursor when more rows exist beyond the requested limit", async () => {
    const rows = [
      movement("m1", new Date("2026-08-01T00:00:00Z")),
      movement("m2", new Date("2026-08-02T00:00:00Z")),
      movement("m3", new Date("2026-08-03T00:00:00Z")),
    ];
    vi.mocked(repository.listStockMovements).mockResolvedValue(rows as never);

    const result = await listStockMovements(tenantId, { limit: 2 });

    expect(result.data).toHaveLength(2);
    expect(result.next_cursor).not.toBeNull();
  });

  it("returns a null next_cursor when the page is partial (end of data)", async () => {
    vi.mocked(repository.listStockMovements).mockResolvedValue([
      movement("m1", new Date("2026-08-01T00:00:00Z")),
    ] as never);

    const result = await listStockMovements(tenantId, { limit: 50 });

    expect(result.next_cursor).toBeNull();
  });

  it("passes product_id/movement_type/date filters through to the repository", async () => {
    vi.mocked(repository.listStockMovements).mockResolvedValue([] as never);

    await listStockMovements(tenantId, {
      limit: 50,
      product_id: productId,
      movement_type: "adjustment",
      date_from: "2026-08-01T00:00:00.000Z",
      date_to: "2026-08-14T00:00:00.000Z",
    });

    expect(repository.listStockMovements).toHaveBeenCalledWith(
      tenantId,
      {
        productId,
        movementType: "adjustment",
        dateFrom: new Date("2026-08-01T00:00:00.000Z"),
        dateTo: new Date("2026-08-14T00:00:00.000Z"),
      },
      null,
      50,
    );
  });

  it("rejects a malformed cursor with VALIDATION_FAILED rather than crashing", async () => {
    await expect(
      listStockMovements(tenantId, { cursor: "not-a-real-cursor!!", limit: 50 }),
    ).rejects.toMatchObject({ status: 422, code: "VALIDATION_FAILED" });
  });
});

describe("getStockBalance", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(storesService.getPrimaryStoreId).mockResolvedValue(storeId);
  });

  it("resolves the tenant's store and returns the summed balance", async () => {
    vi.mocked(repository.findProductById).mockResolvedValue({ id: productId } as never);
    vi.mocked(repository.getStockBalance).mockResolvedValue(8);

    const result = await getStockBalance(tenantId, productId);

    expect(storesService.getPrimaryStoreId).toHaveBeenCalledWith(tenantId);
    expect(repository.getStockBalance).toHaveBeenCalledWith(tenantId, storeId, productId);
    expect(result).toEqual({ product_id: productId, store_id: storeId, balance: 8 });
  });

  it("rejects an unknown product_id with NOT_FOUND", async () => {
    vi.mocked(repository.findProductById).mockResolvedValue(null as never);

    await expect(getStockBalance(tenantId, productId)).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
    expect(repository.getStockBalance).not.toHaveBeenCalled();
  });
});
