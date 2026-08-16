import { describe, expect, it, vi, beforeEach } from "vitest";
import * as identityService from "@/modules/identity/service";
import * as storesService from "@/modules/stores/service";
import * as rolesService from "@/modules/roles/service";
import * as settingsService from "@/modules/settings/service";
import * as posService from "@/modules/pos/service";
import * as repository from "./repository";
import {
  createReturn,
  getReturnDetail,
  approveReturn,
  rejectReturn,
  listReturns,
  listApprovals,
} from "./service";
import type { CreateReturnRequest } from "./schema";

vi.mock("./repository");
vi.mock("@/modules/identity/service");
vi.mock("@/modules/stores/service");
vi.mock("@/modules/roles/service");
vi.mock("@/modules/settings/service");
vi.mock("@/modules/pos/service", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/modules/pos/service")>();
  return { ...actual, getCompletedSaleForReturn: vi.fn() };
});

const authUserId = "11111111-1111-4111-8111-111111111111";
const tenantId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";
const storeId = "44444444-4444-4444-8444-444444444444";
const saleId = "55555555-5555-4555-8555-555555555555";
const returnId = "66666666-6666-4666-8666-666666666666";
const lineItemId1 = "77777777-7777-4777-8777-777777777777";
const lineItemId2 = "88888888-8888-4888-8888-888888888888";
const lineItemId3 = "aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1";
const productId1 = "99999999-9999-4999-8999-999999999999";

function saleWithLineItems(overrides: Partial<{ lineItems: unknown[] }> = {}) {
  return {
    id: saleId,
    tenantId,
    storeId,
    status: "completed",
    lineItems: [
      {
        id: lineItemId1,
        productId: productId1,
        quantity: 3,
        lineTotalMinorUnits: BigInt(3000),
      },
      {
        id: lineItemId2,
        productId: productId1,
        quantity: 1,
        lineTotalMinorUnits: BigInt(1000),
      },
      // Deliberately not evenly divisible by 3 — the case that actually distinguishes the
      // exact-remaining-amount branch from the proportional-rounding branch (specification.md §2).
      {
        id: lineItemId3,
        productId: productId1,
        quantity: 3,
        lineTotalMinorUnits: BigInt(1000),
      },
    ],
    ...overrides,
  };
}

function moneySettings(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    roundingRule: "round_half_up",
    returnAutoApprovalThresholdMinorUnits: BigInt(5000),
    ...overrides,
  };
}

function returnRow(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    id: returnId,
    tenantId,
    storeId,
    originalSaleId: saleId,
    status: "pending_approval",
    refundTotalMinorUnits: BigInt(3000),
    approvedBy: null,
    completedAt: null,
    createdAt: new Date("2026-08-16T00:00:00Z"),
    createdBy: userId,
    lineItems: [
      {
        id: lineItemId1,
        originalSaleLineItemId: lineItemId1,
        quantity: 3,
        refundAmountMinorUnits: BigInt(3000),
      },
    ],
    ...overrides,
  };
}

const baseInput: CreateReturnRequest = {
  id: returnId,
  original_sale_id: saleId,
  line_items: [{ original_sale_line_item_id: lineItemId1, quantity: 3 }],
};

describe("createReturn", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(userId);
    vi.mocked(repository.findReturnById).mockResolvedValue(null);
    vi.mocked(repository.listNonRejectedReturnLineItems).mockResolvedValue([]);
    vi.mocked(settingsService.getMoneySettings).mockResolvedValue(moneySettings() as never);
    vi.mocked(posService.getCompletedSaleForReturn).mockResolvedValue(saleWithLineItems() as never);
  });

  it("auto-approves a return below the shop's threshold", async () => {
    vi.mocked(repository.createReturn).mockResolvedValue(
      returnRow({ status: "completed", completedAt: new Date("2026-08-16T00:00:00Z") }) as never,
    );

    const result = await createReturn(authUserId, tenantId, baseInput);

    expect(repository.createReturn).toHaveBeenCalledWith(
      expect.objectContaining({ status: "completed", refundTotalMinorUnits: BigInt(3000) }),
    );
    expect(result.status).toBe("completed");
  });

  it("creates a pending_approval return above the shop's threshold", async () => {
    vi.mocked(settingsService.getMoneySettings).mockResolvedValue(
      moneySettings({ returnAutoApprovalThresholdMinorUnits: BigInt(500) }) as never,
    );
    vi.mocked(repository.createReturn).mockResolvedValue(returnRow() as never);

    const result = await createReturn(authUserId, tenantId, baseInput);

    expect(repository.createReturn).toHaveBeenCalledWith(
      expect.objectContaining({ status: "pending_approval" }),
    );
    expect(result.status).toBe("pending_approval");
  });

  it("rejects a quantity exceeding what remains with RETURN_QUANTITY_EXCEEDS_SOLD", async () => {
    await expect(
      createReturn(authUserId, tenantId, {
        ...baseInput,
        line_items: [{ original_sale_line_item_id: lineItemId1, quantity: 4 }],
      }),
    ).rejects.toMatchObject({ status: 409, code: "RETURN_QUANTITY_EXCEEDS_SOLD" });
  });

  it("accounts for quantity already consumed by a prior non-rejected return", async () => {
    vi.mocked(repository.listNonRejectedReturnLineItems).mockResolvedValue([
      { originalSaleLineItemId: lineItemId1, quantity: 2, refundAmountMinorUnits: BigInt(2000) },
    ] as never);

    await expect(
      createReturn(authUserId, tenantId, {
        ...baseInput,
        line_items: [{ original_sale_line_item_id: lineItemId1, quantity: 2 }],
      }),
    ).rejects.toMatchObject({ status: 409, code: "RETURN_QUANTITY_EXCEEDS_SOLD" });
  });

  it("rejects a line item id that isn't part of the located sale with NOT_FOUND", async () => {
    await expect(
      createReturn(authUserId, tenantId, {
        ...baseInput,
        line_items: [{ original_sale_line_item_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", quantity: 1 }],
      }),
    ).rejects.toMatchObject({ status: 404, code: "NOT_FOUND" });
  });

  it("rejects a nonexistent/non-completed original sale with ORIGINAL_SALE_NOT_FOUND", async () => {
    vi.mocked(posService.getCompletedSaleForReturn).mockResolvedValue(null);

    await expect(createReturn(authUserId, tenantId, baseInput)).rejects.toMatchObject({
      status: 404,
      code: "ORIGINAL_SALE_NOT_FOUND",
    });
  });

  it("refunds the exact remaining amount for a full-remaining-quantity return, no rounding drift", async () => {
    // 1000 minor units over 1 unit — divides evenly regardless, but this is the line the
    // full-remaining-quantity branch (not the rounding branch) must take.
    vi.mocked(repository.createReturn).mockResolvedValue(returnRow() as never);

    await createReturn(authUserId, tenantId, {
      ...baseInput,
      line_items: [{ original_sale_line_item_id: lineItemId2, quantity: 1 }],
    });

    expect(repository.createReturn).toHaveBeenCalledWith(
      expect.objectContaining({
        lineItems: [expect.objectContaining({ refundAmountMinorUnits: BigInt(1000) })],
      }),
    );
  });

  it("refunds the exact amount for a full return of a not-evenly-divisible line, no drift", async () => {
    // lineItemId3: 1000 minor units over 3 units — 1000/3 is not exact. A full return of all 3
    // must still refund exactly 1000, not a rounded-per-unit-times-3 figure.
    vi.mocked(repository.createReturn).mockResolvedValue(returnRow() as never);

    await createReturn(authUserId, tenantId, {
      ...baseInput,
      line_items: [{ original_sale_line_item_id: lineItemId3, quantity: 3 }],
    });

    expect(repository.createReturn).toHaveBeenCalledWith(
      expect.objectContaining({
        lineItems: [expect.objectContaining({ refundAmountMinorUnits: BigInt(1000) })],
      }),
    );
  });

  it("uses proportional rounding for a genuine partial of a not-evenly-divisible line", async () => {
    // lineItemId3: 1000 minor units over 3 units, returning 1 of 3 → round(1000/3) = 333.
    vi.mocked(repository.createReturn).mockResolvedValue(returnRow() as never);

    await createReturn(authUserId, tenantId, {
      ...baseInput,
      line_items: [{ original_sale_line_item_id: lineItemId3, quantity: 1 }],
    });

    expect(repository.createReturn).toHaveBeenCalledWith(
      expect.objectContaining({
        lineItems: [expect.objectContaining({ refundAmountMinorUnits: BigInt(333) })],
      }),
    );
  });

  it("is an idempotent no-op on a replayed id", async () => {
    vi.mocked(repository.findReturnById).mockResolvedValue(returnRow() as never);

    const result = await createReturn(authUserId, tenantId, baseInput);

    expect(posService.getCompletedSaleForReturn).not.toHaveBeenCalled();
    expect(repository.createReturn).not.toHaveBeenCalled();
    expect(result.id).toBe(returnId);
  });
});

describe("getReturnDetail", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("rejects a nonexistent return with NOT_FOUND", async () => {
    vi.mocked(repository.findReturnById).mockResolvedValue(null);

    await expect(getReturnDetail(tenantId, returnId)).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
  });

  it("returns the formatted return with its line items", async () => {
    vi.mocked(repository.findReturnById).mockResolvedValue(returnRow() as never);

    const result = await getReturnDetail(tenantId, returnId);

    expect(result.id).toBe(returnId);
    expect(result.line_items).toHaveLength(1);
  });
});

describe("approveReturn", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(userId);
    vi.mocked(storesService.getPrimaryStoreId).mockResolvedValue(storeId);
    vi.mocked(posService.getCompletedSaleForReturn).mockResolvedValue(saleWithLineItems() as never);
  });

  it("completes a pending_approval return, writing the stock movement/audit log via the repository", async () => {
    vi.mocked(repository.findReturnById).mockResolvedValue(returnRow() as never);
    vi.mocked(rolesService.resolveActiveRole).mockResolvedValue("manager");
    vi.mocked(repository.completeReturn).mockResolvedValue(
      returnRow({ status: "completed", approvedBy: userId }) as never,
    );

    const result = await approveReturn(authUserId, tenantId, returnId);

    expect(repository.completeReturn).toHaveBeenCalledWith(
      expect.objectContaining({
        returnId,
        approvedBy: userId,
        lineItems: [expect.objectContaining({ id: lineItemId1, productId: productId1, quantity: 3 })],
      }),
    );
    expect(result.status).toBe("completed");
  });

  it("is an idempotent no-op on an already-completed return", async () => {
    vi.mocked(repository.findReturnById).mockResolvedValue(returnRow({ status: "completed" }) as never);

    const result = await approveReturn(authUserId, tenantId, returnId);

    expect(rolesService.resolveActiveRole).not.toHaveBeenCalled();
    expect(repository.completeReturn).not.toHaveBeenCalled();
    expect(result.status).toBe("completed");
  });

  it("rejects an already-rejected return with RETURN_ALREADY_DECIDED", async () => {
    vi.mocked(repository.findReturnById).mockResolvedValue(returnRow({ status: "rejected" }) as never);

    await expect(approveReturn(authUserId, tenantId, returnId)).rejects.toMatchObject({
      status: 409,
      code: "RETURN_ALREADY_DECIDED",
    });
  });

  it("rejects a nonexistent return with NOT_FOUND", async () => {
    vi.mocked(repository.findReturnById).mockResolvedValue(null);

    await expect(approveReturn(authUserId, tenantId, returnId)).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
  });

  it("rejects with PERMISSION_DENIED when the resolved actor role isn't Manager/Owner (DR-017/018)", async () => {
    vi.mocked(repository.findReturnById).mockResolvedValue(returnRow() as never);
    vi.mocked(rolesService.resolveActiveRole).mockResolvedValue("cashier");

    await expect(approveReturn(authUserId, tenantId, returnId)).rejects.toMatchObject({
      status: 403,
      code: "PERMISSION_DENIED",
    });
    expect(repository.completeReturn).not.toHaveBeenCalled();
  });
});

describe("rejectReturn", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(userId);
    vi.mocked(storesService.getPrimaryStoreId).mockResolvedValue(storeId);
  });

  it("rejects a pending_approval return, recording the reason", async () => {
    vi.mocked(repository.findReturnById).mockResolvedValue(returnRow() as never);
    vi.mocked(rolesService.resolveActiveRole).mockResolvedValue("owner");
    vi.mocked(repository.rejectReturn).mockResolvedValue(returnRow({ status: "rejected" }) as never);

    const result = await rejectReturn(authUserId, tenantId, returnId, "Item damaged before return");

    expect(repository.rejectReturn).toHaveBeenCalledWith(
      expect.objectContaining({ returnId, reason: "Item damaged before return" }),
    );
    expect(result.status).toBe("rejected");
  });

  it("is an idempotent no-op on an already-rejected return", async () => {
    vi.mocked(repository.findReturnById).mockResolvedValue(returnRow({ status: "rejected" }) as never);

    await rejectReturn(authUserId, tenantId, returnId, "reason");

    expect(repository.rejectReturn).not.toHaveBeenCalled();
  });

  it("rejects an already-completed return with RETURN_ALREADY_DECIDED", async () => {
    vi.mocked(repository.findReturnById).mockResolvedValue(returnRow({ status: "completed" }) as never);

    await expect(rejectReturn(authUserId, tenantId, returnId, "reason")).rejects.toMatchObject({
      status: 409,
      code: "RETURN_ALREADY_DECIDED",
    });
  });

  it("rejects with PERMISSION_DENIED when the resolved actor role isn't Manager/Owner", async () => {
    vi.mocked(repository.findReturnById).mockResolvedValue(returnRow() as never);
    vi.mocked(rolesService.resolveActiveRole).mockResolvedValue("cashier");

    await expect(rejectReturn(authUserId, tenantId, returnId, "reason")).rejects.toMatchObject({
      status: 403,
      code: "PERMISSION_DENIED",
    });
  });
});

describe("listReturns", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("scopes a Cashier to their own created_by", async () => {
    vi.mocked(repository.listReturns).mockResolvedValue([] as never);

    await listReturns(tenantId, "cashier", userId, { limit: 50 });

    expect(repository.listReturns).toHaveBeenCalledWith(
      tenantId,
      { createdBy: userId, status: undefined },
      null,
      50,
    );
  });

  it("does not scope a Manager/Owner by created_by", async () => {
    vi.mocked(repository.listReturns).mockResolvedValue([] as never);

    await listReturns(tenantId, "owner", userId, { limit: 50 });

    expect(repository.listReturns).toHaveBeenCalledWith(
      tenantId,
      { createdBy: undefined, status: undefined },
      null,
      50,
    );
  });
});

describe("listApprovals", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("always forces status to pending_approval, regardless of caller input", async () => {
    vi.mocked(repository.listReturns).mockResolvedValue([] as never);

    await listApprovals(tenantId, { limit: 50 });

    expect(repository.listReturns).toHaveBeenCalledWith(
      tenantId,
      { status: "pending_approval" },
      null,
      50,
    );
  });
});
