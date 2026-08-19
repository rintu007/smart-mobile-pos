import { describe, expect, it, vi, beforeEach } from "vitest";
import * as productsService from "@/modules/products/service";
import * as posService from "@/modules/pos/service";
import * as customersService from "@/modules/customers/service";
import * as returnsService from "@/modules/returns/service";
import * as stockMovementsRepository from "@/modules/stock-movements/repository";
import * as settingsRepository from "@/modules/settings/repository";
import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import {
  pushOperations,
  pullProducts,
  pullStockMovements,
  pullSales,
  pullShopSettings,
  stockMovementsRetentionCutoff,
} from "./service";
import type { SyncPushRequest } from "./schema";

vi.mock("@/modules/products/service");
vi.mock("@/modules/pos/service");
vi.mock("@/modules/customers/service");
vi.mock("@/modules/returns/service");
vi.mock("@/modules/stock-movements/repository");
vi.mock("@/modules/settings/repository");
vi.mock("./repository");

const authUserId = "11111111-1111-4111-8111-111111111111";
const tenantId = "22222222-2222-4222-8222-222222222222";
const productId = "33333333-3333-4333-8333-333333333333";
const saleId = "44444444-4444-4444-8444-444444444444";
const opProduct = "55555555-5555-4555-8555-555555555555";
const opSale = "66666666-6666-4666-8666-666666666666";
const opCustomer = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const customerId = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const opReturnCreate = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const opReturnApprove = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";
const opReturnReject = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee";
const returnId = "ffffffff-ffff-4fff-8fff-ffffffffffff";
const originalSaleLineItemId = "12121212-1212-4212-8212-121212121212";
const opCustomerUpdate = "13131313-1313-4313-8313-131313131313";

describe("pushOperations", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("processes product.create before sale.create regardless of submitted order, results in original order", async () => {
    vi.mocked(productsService.createProduct).mockResolvedValue({ id: productId } as never);
    vi.mocked(posService.createSale).mockResolvedValue({ id: saleId } as never);

    const callOrder: string[] = [];
    vi.mocked(productsService.createProduct).mockImplementation(async () => {
      callOrder.push("product.create");
      return { id: productId } as never;
    });
    vi.mocked(posService.createSale).mockImplementation(async () => {
      callOrder.push("sale.create");
      return { id: saleId } as never;
    });

    // sale.create submitted first, product.create second.
    const input: SyncPushRequest = {
      operations: [
        {
          type: "sale.create",
          client_operation_id: opSale,
          payload: {
            id: saleId,
            store_id: "77777777-7777-4777-8777-777777777777",
            provisional_invoice_number: "DEV-2026-000001",
            line_items: [{ product_id: productId, quantity: 1, client_unit_price_minor_units: 100 }],
            payments: [{ method: "cash", amount_minor_units: 100 }],
          },
        },
        { type: "product.create", client_operation_id: opProduct, payload: { id: productId, name: "P", price_minor_units: 100 } },
      ],
    };

    const result = await pushOperations(authUserId, tenantId, input);

    expect(callOrder).toEqual(["product.create", "sale.create"]);
    // Results still mirror the request's own original (sale-first) order.
    expect(result.results.map((r) => r.client_operation_id)).toEqual([opSale, opProduct]);
    expect(result.results.every((r) => r.status === "accepted")).toBe(true);
  });

  it("rejects a payload that fails the direct endpoint's own schema, without calling the service", async () => {
    const input: SyncPushRequest = {
      operations: [
        { type: "product.create", client_operation_id: opProduct, payload: { name: "no id or price" } },
      ],
    };

    const result = await pushOperations(authUserId, tenantId, input);

    expect(result.results[0]).toMatchObject({ status: "rejected", error: { code: "VALIDATION_FAILED" } });
    expect(productsService.createProduct).not.toHaveBeenCalled();
  });

  it("remaps a sale.create's NOT_FOUND to DEPENDENCY_NOT_FOUND", async () => {
    vi.mocked(posService.createSale).mockRejectedValue(
      new ApiError(404, "NOT_FOUND", "Product not found."),
    );

    const input: SyncPushRequest = {
      operations: [
        {
          type: "sale.create",
          client_operation_id: opSale,
          payload: {
            id: saleId,
            store_id: "77777777-7777-4777-8777-777777777777",
            provisional_invoice_number: "DEV-2026-000001",
            line_items: [{ product_id: productId, quantity: 1, client_unit_price_minor_units: 100 }],
            payments: [{ method: "cash", amount_minor_units: 100 }],
          },
        },
      ],
    };

    const result = await pushOperations(authUserId, tenantId, input);

    expect(result.results[0]).toMatchObject({ status: "rejected", error: { code: "DEPENDENCY_NOT_FOUND" } });
  });

  it("dispatches customer.create to customersService.createCustomer", async () => {
    vi.mocked(customersService.createCustomer).mockResolvedValue({ id: customerId } as never);

    const input: SyncPushRequest = {
      operations: [
        {
          type: "customer.create",
          client_operation_id: opCustomer,
          payload: { id: customerId, phone: "9876543210" },
        },
      ],
    };

    const result = await pushOperations(authUserId, tenantId, input);

    expect(customersService.createCustomer).toHaveBeenCalledWith(authUserId, tenantId, {
      id: customerId,
      phone: "9876543210",
    });
    expect(result.results[0]).toMatchObject({ status: "accepted", entity_id: customerId });
  });

  it("rejects a customer.create payload that fails the direct endpoint's own schema", async () => {
    const input: SyncPushRequest = {
      operations: [
        // Missing `id` entirely -- a real Zod-schema-level failure, distinct from
        // CUSTOMER_IDENTIFIER_REQUIRED (a service-layer check that runs only once a
        // schema-valid payload reaches customersService.createCustomer, per customers/
        // specification.md §5's live-found `.refine()` fix -- name/phone alone omitted is not,
        // by itself, a schema failure).
        { type: "customer.create", client_operation_id: opCustomer, payload: { phone: "9876543210" } },
      ],
    };

    const result = await pushOperations(authUserId, tenantId, input);

    expect(result.results[0]).toMatchObject({ status: "rejected", error: { code: "VALIDATION_FAILED" } });
    expect(customersService.createCustomer).not.toHaveBeenCalled();
  });

  it("dispatches customer.update to customersService.updateCustomer", async () => {
    vi.mocked(customersService.updateCustomer).mockResolvedValue({ id: customerId } as never);

    const input: SyncPushRequest = {
      operations: [
        {
          type: "customer.update",
          client_operation_id: opCustomerUpdate,
          payload: {
            id: customerId,
            base_updated_at: "2026-08-16T00:00:00.000Z",
            base_name: "Ramesh Kumar",
            base_phone: "9876543210",
            name: "Ramesh Kumar",
            phone: "9111111111",
          },
        },
      ],
    };

    const result = await pushOperations(authUserId, tenantId, input);

    expect(customersService.updateCustomer).toHaveBeenCalledWith(authUserId, tenantId, customerId, {
      base_updated_at: "2026-08-16T00:00:00.000Z",
      base_name: "Ramesh Kumar",
      base_phone: "9876543210",
      name: "Ramesh Kumar",
      phone: "9111111111",
    });
    expect(result.results[0]).toMatchObject({ status: "accepted", entity_id: customerId });
  });

  it("rejects a customer.update payload missing a required base field", async () => {
    const input: SyncPushRequest = {
      operations: [
        {
          type: "customer.update",
          client_operation_id: opCustomerUpdate,
          payload: { id: customerId, base_updated_at: "2026-08-16T00:00:00.000Z" },
        },
      ],
    };

    const result = await pushOperations(authUserId, tenantId, input);

    expect(result.results[0]).toMatchObject({ status: "rejected", error: { code: "VALIDATION_FAILED" } });
    expect(customersService.updateCustomer).not.toHaveBeenCalled();
  });

  it("processes customer.update before sale.create, same as customer.create", async () => {
    const callOrder: string[] = [];
    vi.mocked(customersService.updateCustomer).mockImplementation(async () => {
      callOrder.push("customer.update");
      return { id: customerId } as never;
    });
    vi.mocked(posService.createSale).mockImplementation(async () => {
      callOrder.push("sale.create");
      return { id: saleId } as never;
    });

    const input: SyncPushRequest = {
      operations: [
        {
          type: "sale.create",
          client_operation_id: opSale,
          payload: {
            id: saleId,
            store_id: "77777777-7777-4777-8777-777777777777",
            provisional_invoice_number: "DEV-2026-000001",
            line_items: [{ product_id: productId, quantity: 1, client_unit_price_minor_units: 100 }],
            payments: [{ method: "cash", amount_minor_units: 100 }],
          },
        },
        {
          type: "customer.update",
          client_operation_id: opCustomerUpdate,
          payload: {
            id: customerId,
            base_updated_at: "2026-08-16T00:00:00.000Z",
            base_name: "Ramesh Kumar",
            base_phone: "9876543210",
            name: "Ramesh Kumar",
            phone: "9111111111",
          },
        },
      ],
    };

    await pushOperations(authUserId, tenantId, input);

    expect(callOrder).toEqual(["customer.update", "sale.create"]);
  });

  it("processes customer.create before sale.create, same as product.create", async () => {
    const callOrder: string[] = [];
    vi.mocked(customersService.createCustomer).mockImplementation(async () => {
      callOrder.push("customer.create");
      return { id: customerId } as never;
    });
    vi.mocked(posService.createSale).mockImplementation(async () => {
      callOrder.push("sale.create");
      return { id: saleId } as never;
    });

    const input: SyncPushRequest = {
      operations: [
        {
          type: "sale.create",
          client_operation_id: opSale,
          payload: {
            id: saleId,
            store_id: "77777777-7777-4777-8777-777777777777",
            provisional_invoice_number: "DEV-2026-000001",
            line_items: [{ product_id: productId, quantity: 1, client_unit_price_minor_units: 100 }],
            payments: [{ method: "cash", amount_minor_units: 100 }],
            customer_id: customerId,
          },
        },
        {
          type: "customer.create",
          client_operation_id: opCustomer,
          payload: { id: customerId, phone: "9876543210" },
        },
      ],
    };

    await pushOperations(authUserId, tenantId, input);

    expect(callOrder).toEqual(["customer.create", "sale.create"]);
  });

  it("dispatches return.create to returnsService.createReturn", async () => {
    vi.mocked(returnsService.createReturn).mockResolvedValue({ id: returnId } as never);

    const input: SyncPushRequest = {
      operations: [
        {
          type: "return.create",
          client_operation_id: opReturnCreate,
          payload: {
            id: returnId,
            original_sale_id: saleId,
            line_items: [{ original_sale_line_item_id: originalSaleLineItemId, quantity: 1 }],
          },
        },
      ],
    };

    const result = await pushOperations(authUserId, tenantId, input);

    expect(returnsService.createReturn).toHaveBeenCalledWith(authUserId, tenantId, {
      id: returnId,
      original_sale_id: saleId,
      line_items: [{ original_sale_line_item_id: originalSaleLineItemId, quantity: 1 }],
    });
    expect(result.results[0]).toMatchObject({ status: "accepted", entity_id: returnId });
  });

  it("processes return.create after sale.create", async () => {
    const callOrder: string[] = [];
    vi.mocked(posService.createSale).mockImplementation(async () => {
      callOrder.push("sale.create");
      return { id: saleId } as never;
    });
    vi.mocked(returnsService.createReturn).mockImplementation(async () => {
      callOrder.push("return.create");
      return { id: returnId } as never;
    });

    const input: SyncPushRequest = {
      operations: [
        {
          type: "return.create",
          client_operation_id: opReturnCreate,
          payload: {
            id: returnId,
            original_sale_id: saleId,
            line_items: [{ original_sale_line_item_id: originalSaleLineItemId, quantity: 1 }],
          },
        },
        {
          type: "sale.create",
          client_operation_id: opSale,
          payload: {
            id: saleId,
            store_id: "77777777-7777-4777-8777-777777777777",
            provisional_invoice_number: "DEV-2026-000001",
            line_items: [{ product_id: productId, quantity: 1, client_unit_price_minor_units: 100 }],
            payments: [{ method: "cash", amount_minor_units: 100 }],
          },
        },
      ],
    };

    await pushOperations(authUserId, tenantId, input);

    expect(callOrder).toEqual(["sale.create", "return.create"]);
  });

  it("dispatches return.approve to returnsService.approveReturn", async () => {
    vi.mocked(returnsService.approveReturn).mockResolvedValue({ id: returnId } as never);

    const input: SyncPushRequest = {
      operations: [
        { type: "return.approve", client_operation_id: opReturnApprove, payload: { id: returnId } },
      ],
    };

    const result = await pushOperations(authUserId, tenantId, input);

    expect(returnsService.approveReturn).toHaveBeenCalledWith(authUserId, tenantId, returnId);
    expect(result.results[0]).toMatchObject({ status: "accepted", entity_id: returnId });
  });

  it("dispatches return.reject to returnsService.rejectReturn, carrying the reason", async () => {
    vi.mocked(returnsService.rejectReturn).mockResolvedValue({ id: returnId } as never);

    const input: SyncPushRequest = {
      operations: [
        {
          type: "return.reject",
          client_operation_id: opReturnReject,
          payload: { id: returnId, reason: "Customer changed mind" },
        },
      ],
    };

    const result = await pushOperations(authUserId, tenantId, input);

    expect(returnsService.rejectReturn).toHaveBeenCalledWith(
      authUserId,
      tenantId,
      returnId,
      "Customer changed mind",
    );
    expect(result.results[0]).toMatchObject({ status: "accepted", entity_id: returnId });
  });

  it("remaps a return.create's ORIGINAL_SALE_NOT_FOUND to DEPENDENCY_NOT_FOUND", async () => {
    vi.mocked(returnsService.createReturn).mockRejectedValue(
      new ApiError(404, "ORIGINAL_SALE_NOT_FOUND", "Sale not found."),
    );

    const input: SyncPushRequest = {
      operations: [
        {
          type: "return.create",
          client_operation_id: opReturnCreate,
          payload: {
            id: returnId,
            original_sale_id: saleId,
            line_items: [{ original_sale_line_item_id: originalSaleLineItemId, quantity: 1 }],
          },
        },
      ],
    };

    const result = await pushOperations(authUserId, tenantId, input);

    expect(result.results[0]).toMatchObject({
      status: "rejected",
      error: { code: "DEPENDENCY_NOT_FOUND" },
    });
  });

  it("rejects a return.approve payload missing id with VALIDATION_FAILED", async () => {
    const input: SyncPushRequest = {
      operations: [{ type: "return.approve", client_operation_id: opReturnApprove, payload: {} }],
    };

    const result = await pushOperations(authUserId, tenantId, input);

    expect(result.results[0]).toMatchObject({ status: "rejected", error: { code: "VALIDATION_FAILED" } });
    expect(returnsService.approveReturn).not.toHaveBeenCalled();
  });

  it("does not let one operation's rejection stop the rest from running", async () => {
    vi.mocked(productsService.createProduct)
      .mockRejectedValueOnce(new ApiError(422, "VALIDATION_FAILED", "bad"))
      .mockResolvedValueOnce({ id: productId } as never);

    const secondProductOp = "88888888-8888-4888-8888-888888888888";
    const secondProductId = "99999999-9999-4999-8999-999999999999";
    const input: SyncPushRequest = {
      operations: [
        { type: "product.create", client_operation_id: opProduct, payload: { id: productId, name: "A", price_minor_units: 1 } },
        { type: "product.create", client_operation_id: secondProductOp, payload: { id: secondProductId, name: "B", price_minor_units: 1 } },
      ],
    };

    const result = await pushOperations(authUserId, tenantId, input);

    expect(result.results[0]?.status).toBe("rejected");
    expect(result.results[1]?.status).toBe("accepted");
  });
});

describe("pullProducts", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  const product = (id: string, updatedAt: Date) => ({
    id,
    name: "P",
    priceMinorUnits: BigInt(100),
    categoryId: null,
    unitId: null,
    sku: null,
    barcode: null,
    createdAt: updatedAt,
    updatedAt,
  });

  it("returns a non-null next_cursor when more rows exist beyond the requested limit", async () => {
    // repository.listProductsForSync is asked for limit + 1 (the "peek" — see repository.ts) —
    // returning 3 rows for a limit of 2 is what signals "there's a next page."
    const rows = [
      product("p1", new Date("2026-08-01T00:00:00Z")),
      product("p2", new Date("2026-08-02T00:00:00Z")),
      product("p3", new Date("2026-08-03T00:00:00Z")),
    ];
    vi.mocked(repository.listProductsForSync).mockResolvedValue(rows as never);

    const result = await pullProducts(tenantId, undefined, 2);

    expect(result.data).toHaveLength(2);
    expect(result.data.map((p) => p.id)).toEqual(["p1", "p2"]);
    expect(result.next_cursor).not.toBeNull();
  });

  it("returns a null next_cursor when the page is partial (end of data)", async () => {
    const rows = [product("p1", new Date("2026-08-01T00:00:00Z"))];
    vi.mocked(repository.listProductsForSync).mockResolvedValue(rows as never);

    const result = await pullProducts(tenantId, undefined, 50);

    expect(result.next_cursor).toBeNull();
  });

  it("decodes a cursor and passes it through to the repository", async () => {
    vi.mocked(repository.listProductsForSync).mockResolvedValue([]);
    const updatedAt = new Date("2026-08-01T00:00:00Z");
    const cursor = Buffer.from(`${updatedAt.toISOString()}|p1`).toString("base64url");

    await pullProducts(tenantId, cursor, 50);

    expect(repository.listProductsForSync).toHaveBeenCalledWith(
      tenantId,
      { updatedAt, id: "p1" },
      50,
    );
  });

  it("rejects a malformed cursor with VALIDATION_FAILED rather than crashing", async () => {
    await expect(pullProducts(tenantId, "not-a-real-cursor!!", 50)).rejects.toMatchObject({
      status: 422,
      code: "VALIDATION_FAILED",
    });
  });

  it("carries category_id/unit_id/sku/barcode through the pull response (Sprint 21 fix)", async () => {
    const row = {
      id: "p1",
      name: "Amul Milk",
      priceMinorUnits: BigInt(2800),
      categoryId: "cat-1",
      unitId: "unit-1",
      sku: "AML-500",
      barcode: "8901234567890",
      createdAt: new Date("2026-08-01T00:00:00Z"),
      updatedAt: new Date("2026-08-01T00:00:00Z"),
    };
    vi.mocked(repository.listProductsForSync).mockResolvedValue([row] as never);

    const result = await pullProducts(tenantId, undefined, 50);

    expect(result.data[0]).toMatchObject({
      category_id: "cat-1",
      unit_id: "unit-1",
      sku: "AML-500",
      barcode: "8901234567890",
    });
  });
});

describe("stockMovementsRetentionCutoff", () => {
  it("returns the prior financial year's start for a date well within the current FY", () => {
    expect(stockMovementsRetentionCutoff(new Date("2026-08-15T00:00:00Z"))).toEqual(
      new Date("2025-04-01T00:00:00Z"),
    );
  });

  it("rolls over correctly for a date just before the April 1 FY boundary", () => {
    expect(stockMovementsRetentionCutoff(new Date("2026-03-31T23:59:59Z"))).toEqual(
      new Date("2024-04-01T00:00:00Z"),
    );
  });

  it("rolls over correctly for a date exactly at the April 1 FY boundary", () => {
    expect(stockMovementsRetentionCutoff(new Date("2026-04-01T00:00:00Z"))).toEqual(
      new Date("2025-04-01T00:00:00Z"),
    );
  });
});

describe("pullStockMovements", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  const movement = (id: string, createdAt: Date) => ({
    id,
    productId: "p1",
    storeId: "store-1",
    quantityDelta: -2,
    movementType: "sale",
    reasonCode: null,
    referenceType: null,
    referenceId: null,
    createdAt,
  });

  it("returns has_more true and a next_cursor from the last row when more exist beyond limit", async () => {
    const rows = [
      movement("m1", new Date("2026-08-01T00:00:00Z")),
      movement("m2", new Date("2026-08-02T00:00:00Z")),
      movement("m3", new Date("2026-08-03T00:00:00Z")),
    ];
    vi.mocked(stockMovementsRepository.listStockMovements).mockResolvedValue(rows as never);

    const result = await pullStockMovements(tenantId, undefined, 2);

    expect(result.data).toHaveLength(2);
    expect(result.has_more).toBe(true);
    expect(result.next_cursor).not.toBeNull();
  });

  it("echoes the caller's own cursor back, not null, when no new rows exist since it", async () => {
    vi.mocked(stockMovementsRepository.listStockMovements).mockResolvedValue([]);
    const createdAt = new Date("2026-08-01T00:00:00Z");
    const cursor = Buffer.from(`${createdAt.toISOString()}|m1`).toString("base64url");

    const result = await pullStockMovements(tenantId, cursor, 50);

    expect(result.next_cursor).toBe(cursor);
    expect(result.has_more).toBe(false);
  });

  it("returns a null next_cursor only when there is truly nothing to resume from", async () => {
    vi.mocked(stockMovementsRepository.listStockMovements).mockResolvedValue([]);

    const result = await pullStockMovements(tenantId, undefined, 50);

    expect(result.next_cursor).toBeNull();
  });

  it(
    "passes a tenant-scoped query bounded to the current + prior financial year (Sprint 53 — " +
      "was unfiltered before, inbound-sync.md §4's own retention window was never actually applied)",
    async () => {
      vi.mocked(stockMovementsRepository.listStockMovements).mockResolvedValue([]);
      const now = new Date("2026-08-15T00:00:00Z"); // within FY2026 (started 2026-04-01)

      await pullStockMovements(tenantId, undefined, 50, now);

      expect(stockMovementsRepository.listStockMovements).toHaveBeenCalledWith(
        tenantId,
        { dateFrom: new Date("2025-04-01T00:00:00Z") },
        null,
        50,
      );
    },
  );

  it("rejects a malformed cursor with VALIDATION_FAILED rather than crashing", async () => {
    await expect(pullStockMovements(tenantId, "not-a-real-cursor!!", 50)).rejects.toMatchObject({
      status: 422,
      code: "VALIDATION_FAILED",
    });
  });
});

describe("pullSales", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  const sale = (id: string, completedAt: Date) => ({
    id,
    status: "completed",
    tradingDayId: null,
    customerId: null,
    provisionalInvoiceNumber: "DEV-2026-000001",
    canonicalInvoiceNumber: null,
    financialYear: null,
    subtotalMinorUnits: BigInt(100),
    discountTotalMinorUnits: BigInt(0),
    taxTotalMinorUnits: BigInt(0),
    taxRegistrationTypeAtSale: null,
    grandTotalMinorUnits: BigInt(100),
    completedAt,
    createdAt: completedAt,
    lineItems: [],
    payments: [],
  });

  it("returns has_more true and a next_cursor from the last row when more exist beyond limit", async () => {
    const rows = [
      sale("s1", new Date("2026-08-01T00:00:00Z")),
      sale("s2", new Date("2026-08-02T00:00:00Z")),
      sale("s3", new Date("2026-08-03T00:00:00Z")),
    ];
    vi.mocked(repository.listSalesForSync).mockResolvedValue(rows as never);
    vi.mocked(posService.formatSale).mockImplementation((s) => ({ id: s.id }) as never);

    const result = await pullSales(tenantId, undefined, 2);

    expect(result.data).toHaveLength(2);
    expect(result.has_more).toBe(true);
    expect(result.next_cursor).not.toBeNull();
  });

  it("includes created_at alongside formatSale's own shape", async () => {
    const completedAt = new Date("2026-08-01T00:00:00Z");
    vi.mocked(repository.listSalesForSync).mockResolvedValue([sale("s1", completedAt)] as never);
    vi.mocked(posService.formatSale).mockReturnValue({ id: "s1" } as never);

    const result = await pullSales(tenantId, undefined, 50);

    expect(result.data[0]).toMatchObject({ id: "s1", created_at: completedAt.toISOString() });
  });

  it("echoes the caller's own cursor back, not null, when no new sales exist since it", async () => {
    vi.mocked(repository.listSalesForSync).mockResolvedValue([]);
    const completedAt = new Date("2026-08-01T00:00:00Z");
    const cursor = Buffer.from(`${completedAt.toISOString()}|s1`).toString("base64url");

    const result = await pullSales(tenantId, cursor, 50);

    expect(result.next_cursor).toBe(cursor);
  });

  it("rejects a malformed cursor with VALIDATION_FAILED rather than crashing", async () => {
    await expect(pullSales(tenantId, "not-a-real-cursor!!", 50)).rejects.toMatchObject({
      status: 422,
      code: "VALIDATION_FAILED",
    });
  });
});

describe("pullShopSettings", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("returns the tenant's row wrapped in the standard envelope, cursor/has_more always null/false", async () => {
    vi.mocked(settingsRepository.findSettings).mockResolvedValue({
      lowStockThresholdQuantity: 8,
      receiptTemplateConfig: null,
    } as never);

    const result = await pullShopSettings(tenantId);

    expect(result).toEqual({
      data: [{ low_stock_threshold_quantity: 8, receipt_footer_message: null }],
      next_cursor: null,
      has_more: false,
    });
  });

  it("returns an empty data array rather than throwing when no row exists", async () => {
    vi.mocked(settingsRepository.findSettings).mockResolvedValue(null);

    const result = await pullShopSettings(tenantId);

    expect(result.data).toEqual([]);
  });

  it("includes receipt_footer_message when receipt_template_config has been set (Sprint 39)", async () => {
    vi.mocked(settingsRepository.findSettings).mockResolvedValue({
      lowStockThresholdQuantity: 5,
      receiptTemplateConfig: { footer_message: "See you soon!" },
    } as never);

    const result = await pullShopSettings(tenantId);

    expect(result.data).toEqual([
      { low_stock_threshold_quantity: 5, receipt_footer_message: "See you soon!" },
    ]);
  });
});
