import { Prisma } from "@prisma/client";
import { describe, expect, it, vi, beforeEach } from "vitest";
import * as identityService from "@/modules/identity/service";
import * as repository from "./repository";
import {
  createCustomer,
  updateCustomer,
  deactivateCustomer,
  listCustomers,
  getPurchaseHistory,
} from "./service";
import type { CreateCustomerRequest } from "./schema";

vi.mock("./repository");
vi.mock("@/modules/identity/service");

const authUserId = "11111111-1111-4111-8111-111111111111";
const tenantId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";
const customerId = "44444444-4444-4444-8444-444444444444";

const baseInput: CreateCustomerRequest = {
  id: customerId,
  name: "Ramesh Kumar",
  phone: "9876543210",
};

function uniqueConstraintError() {
  return new Prisma.PrismaClientKnownRequestError("Unique constraint failed", {
    code: "P2002",
    clientVersion: "test",
    meta: { target: ["tenant_id", "phone"] },
  });
}

function customerRow(overrides: Partial<{
  id: string;
  name: string | null;
  phone: string | null;
  deactivatedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}> = {}) {
  return {
    id: customerId,
    name: "Ramesh Kumar",
    phone: "9876543210",
    deactivatedAt: null,
    createdAt: new Date("2026-08-16T00:00:00Z"),
    updatedAt: new Date("2026-08-16T00:00:00Z"),
    ...overrides,
  };
}

describe("createCustomer", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(userId);
  });

  it("creates a customer with both name and phone", async () => {
    vi.mocked(repository.createCustomer).mockResolvedValue(customerRow() as never);

    const result = await createCustomer(authUserId, tenantId, baseInput);

    expect(identityService.resolveUserId).toHaveBeenCalledWith(authUserId);
    expect(repository.createCustomer).toHaveBeenCalledWith({
      ...baseInput,
      tenantId,
      createdBy: userId,
    });
    expect(result).toEqual({
      id: customerId,
      name: "Ramesh Kumar",
      phone: "9876543210",
      created_at: "2026-08-16T00:00:00.000Z",
      updated_at: "2026-08-16T00:00:00.000Z",
    });
  });

  it("creates a customer with only a phone", async () => {
    vi.mocked(repository.createCustomer).mockResolvedValue(
      customerRow({ name: null }) as never,
    );

    const result = await createCustomer(authUserId, tenantId, {
      id: customerId,
      phone: "9876543210",
    });

    expect(result.name).toBeNull();
  });

  it("creates a customer with only a name", async () => {
    vi.mocked(repository.createCustomer).mockResolvedValue(
      customerRow({ phone: null }) as never,
    );

    const result = await createCustomer(authUserId, tenantId, {
      id: customerId,
      name: "Ramesh Kumar",
    });

    expect(result.phone).toBeNull();
  });

  it("rejects a customer with neither name nor phone with CUSTOMER_IDENTIFIER_REQUIRED", async () => {
    await expect(
      createCustomer(authUserId, tenantId, { id: customerId } as CreateCustomerRequest),
    ).rejects.toMatchObject({ status: 422, code: "CUSTOMER_IDENTIFIER_REQUIRED" });
    expect(repository.createCustomer).not.toHaveBeenCalled();
  });

  it("translates a phone unique-constraint violation into PHONE_ALREADY_ASSIGNED", async () => {
    vi.mocked(repository.createCustomer).mockRejectedValue(uniqueConstraintError());

    await expect(createCustomer(authUserId, tenantId, baseInput)).rejects.toMatchObject({
      status: 409,
      code: "PHONE_ALREADY_ASSIGNED",
    });
  });
});

describe("updateCustomer", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("updates just the name, leaving phone unchanged", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(customerRow() as never);
    vi.mocked(repository.updateCustomer).mockResolvedValue(
      customerRow({ name: "New Name" }) as never,
    );

    const result = await updateCustomer(tenantId, customerId, { name: "New Name" });

    expect(repository.updateCustomer).toHaveBeenCalledWith(customerId, { name: "New Name" });
    expect(result.name).toBe("New Name");
    expect(result.phone).toBe("9876543210");
  });

  it("rejects a PATCH targeting a nonexistent customer with NOT_FOUND", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(null);

    await expect(
      updateCustomer(tenantId, customerId, { name: "New Name" }),
    ).rejects.toMatchObject({ status: 404, code: "NOT_FOUND" });
    expect(repository.updateCustomer).not.toHaveBeenCalled();
  });

  it("rejects a PATCH that would clear the only identifier a customer has", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(
      customerRow({ name: null }) as never,
    );

    await expect(
      updateCustomer(tenantId, customerId, { phone: null }),
    ).rejects.toMatchObject({ status: 422, code: "CUSTOMER_IDENTIFIER_REQUIRED" });
    expect(repository.updateCustomer).not.toHaveBeenCalled();
  });

  it("allows clearing phone when name is still present", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(customerRow() as never);
    vi.mocked(repository.updateCustomer).mockResolvedValue(
      customerRow({ phone: null }) as never,
    );

    const result = await updateCustomer(tenantId, customerId, { phone: null });

    expect(result.phone).toBeNull();
  });

  it("translates a phone unique-constraint violation into PHONE_ALREADY_ASSIGNED", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(customerRow() as never);
    vi.mocked(repository.updateCustomer).mockRejectedValue(uniqueConstraintError());

    await expect(
      updateCustomer(tenantId, customerId, { phone: "1111111111" }),
    ).rejects.toMatchObject({ status: 409, code: "PHONE_ALREADY_ASSIGNED" });
  });
});

describe("deactivateCustomer", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("sets deactivated_at on an active customer", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(customerRow() as never);
    vi.mocked(repository.deactivateCustomer).mockResolvedValue(
      customerRow({ deactivatedAt: new Date("2026-08-16T01:00:00Z") }) as never,
    );

    const result = await deactivateCustomer(tenantId, customerId);

    expect(repository.deactivateCustomer).toHaveBeenCalledWith(customerId);
    expect(result.id).toBe(customerId);
  });

  it("is an idempotent no-op on an already-deactivated customer", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(
      customerRow({ deactivatedAt: new Date("2026-08-16T01:00:00Z") }) as never,
    );

    await deactivateCustomer(tenantId, customerId);

    expect(repository.deactivateCustomer).not.toHaveBeenCalled();
  });

  it("rejects a nonexistent customer with NOT_FOUND", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(null);

    await expect(deactivateCustomer(tenantId, customerId)).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
  });
});

describe("listCustomers", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("filters by an exact phone match", async () => {
    vi.mocked(repository.listCustomers).mockResolvedValue([] as never);

    await listCustomers(tenantId, { limit: 50, phone: "9876543210" });

    expect(repository.listCustomers).toHaveBeenCalledWith(
      tenantId,
      { phone: "9876543210" },
      null,
      50,
    );
  });

  it("returns a non-null next_cursor when more rows exist beyond the requested limit", async () => {
    const rows = [
      customerRow({ id: "c1", updatedAt: new Date("2026-08-01T00:00:00Z") }),
      customerRow({ id: "c2", updatedAt: new Date("2026-08-02T00:00:00Z") }),
      customerRow({ id: "c3", updatedAt: new Date("2026-08-03T00:00:00Z") }),
    ];
    vi.mocked(repository.listCustomers).mockResolvedValue(rows as never);

    const result = await listCustomers(tenantId, { limit: 2 });

    expect(result.data).toHaveLength(2);
    expect(result.next_cursor).not.toBeNull();
  });

  it("rejects a malformed cursor with VALIDATION_FAILED rather than crashing", async () => {
    await expect(
      listCustomers(tenantId, { cursor: "not-a-real-cursor!!", limit: 50 }),
    ).rejects.toMatchObject({ status: 422, code: "VALIDATION_FAILED" });
  });
});

describe("getPurchaseHistory", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("rejects a nonexistent customer with NOT_FOUND", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(null);

    await expect(getPurchaseHistory(tenantId, customerId, { limit: 50 })).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
    expect(repository.listPurchaseHistory).not.toHaveBeenCalled();
  });

  it("maps completed sales into the response shape", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(customerRow() as never);
    vi.mocked(repository.listPurchaseHistory).mockResolvedValue([
      {
        id: "sale-1",
        provisionalInvoiceNumber: "DEV001-2026-000001",
        grandTotalMinorUnits: BigInt(3500),
        completedAt: new Date("2026-08-15T00:00:00Z"),
      },
    ] as never);

    const result = await getPurchaseHistory(tenantId, customerId, { limit: 50 });

    expect(result.data).toEqual([
      {
        id: "sale-1",
        provisional_invoice_number: "DEV001-2026-000001",
        grand_total_minor_units: 3500,
        completed_at: "2026-08-15T00:00:00.000Z",
      },
    ]);
  });

  it("returns a non-null next_cursor when more rows exist beyond the requested limit", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(customerRow() as never);
    const sale = (id: string, completedAt: Date) => ({
      id,
      provisionalInvoiceNumber: "DEV001-2026-000001",
      grandTotalMinorUnits: BigInt(1000),
      completedAt,
    });
    vi.mocked(repository.listPurchaseHistory).mockResolvedValue([
      sale("s1", new Date("2026-08-03T00:00:00Z")),
      sale("s2", new Date("2026-08-02T00:00:00Z")),
      sale("s3", new Date("2026-08-01T00:00:00Z")),
    ] as never);

    const result = await getPurchaseHistory(tenantId, customerId, { limit: 2 });

    expect(result.data).toHaveLength(2);
    expect(result.next_cursor).not.toBeNull();
  });
});
