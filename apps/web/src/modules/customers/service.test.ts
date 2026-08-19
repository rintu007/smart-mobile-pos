import { Prisma } from "@prisma/client";
import { describe, expect, it, vi, beforeEach } from "vitest";
import * as identityService from "@/modules/identity/service";
import * as repository from "./repository";
import {
  createCustomer,
  updateCustomer,
  deactivateCustomer,
  eraseCustomer,
  listCustomers,
  getPurchaseHistory,
  listConflicts,
  resolveConflict,
} from "./service";
import type { CreateCustomerRequest, UpdateCustomerRequest } from "./schema";

vi.mock("./repository");
vi.mock("@/modules/identity/service");

const authUserId = "11111111-1111-4111-8111-111111111111";
const tenantId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333"; // Priya, Cashier
const managerUserId = "77777777-7777-4777-8777-777777777777"; // Anil, Manager
const customerId = "44444444-4444-4444-8444-444444444444";
const conflictId = "88888888-8888-4888-8888-888888888888";

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
  erasedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  createdBy: string;
  updatedBy: string | null;
}> = {}) {
  return {
    id: customerId,
    name: "Ramesh Kumar",
    phone: "9876543210",
    deactivatedAt: null,
    erasedAt: null,
    createdAt: new Date("2026-08-16T00:00:00Z"),
    updatedAt: new Date("2026-08-16T00:00:00Z"),
    createdBy: userId,
    updatedBy: null,
    ...overrides,
  };
}

// Every field must be sent, even when unchanged (§1c) — base === value means "not touched."
function patchInput(overrides: Partial<UpdateCustomerRequest> = {}): UpdateCustomerRequest {
  return {
    base_updated_at: "2026-08-16T00:00:00.000Z",
    base_name: "Ramesh Kumar",
    base_phone: "9876543210",
    name: "Ramesh Kumar",
    phone: "9876543210",
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
      deactivated_at: null,
      erased_at: null,
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
    vi.mocked(identityService.resolveUserId).mockResolvedValue(userId);
  });

  it("applies a field outright when nobody else has touched it (base === current)", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(customerRow() as never);
    vi.mocked(repository.updateCustomerFields).mockResolvedValue(
      customerRow({ name: "New Name", updatedBy: userId }) as never,
    );

    const result = await updateCustomer(
      authUserId,
      tenantId,
      customerId,
      patchInput({ name: "New Name" }),
    );

    expect(repository.updateCustomerFields).toHaveBeenCalledWith(
      customerId,
      { name: "New Name" },
      userId,
    );
    expect(repository.createFieldConflicts).not.toHaveBeenCalled();
    expect(result.name).toBe("New Name");
  });

  it("is a no-op when base === value for every field (nothing actually changed)", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(customerRow() as never);

    const result = await updateCustomer(authUserId, tenantId, customerId, patchInput());

    expect(repository.updateCustomerFields).not.toHaveBeenCalled();
    expect(result.name).toBe("Ramesh Kumar");
  });

  it("applies non-overlapping fields from two independent edits, neither conflicting", async () => {
    // Device A changes name only; phone's base already equals current (nobody touched it).
    vi.mocked(repository.findCustomerById).mockResolvedValue(customerRow() as never);
    vi.mocked(repository.updateCustomerFields).mockResolvedValue(
      customerRow({ name: "New Name" }) as never,
    );
    await updateCustomer(
      authUserId,
      tenantId,
      customerId,
      patchInput({ name: "New Name" }),
    );
    expect(repository.updateCustomerFields).toHaveBeenCalledWith(
      customerId,
      { name: "New Name" },
      userId,
    );

    // Device B (Manager), concurrently, changes phone only against the *post-A* current row —
    // its own base for phone still matches current (A never touched phone), so it applies cleanly.
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(managerUserId);
    vi.mocked(repository.findCustomerById).mockResolvedValue(
      customerRow({ name: "New Name", updatedBy: userId }) as never,
    );
    vi.mocked(repository.updateCustomerFields).mockResolvedValue(
      customerRow({ name: "New Name", phone: "9111111111", updatedBy: managerUserId }) as never,
    );

    await updateCustomer(
      authUserId,
      tenantId,
      customerId,
      patchInput({ base_name: "New Name", name: "New Name", phone: "9111111111" }),
    );

    expect(repository.updateCustomerFields).toHaveBeenCalledWith(
      customerId,
      { phone: "9111111111" },
      managerUserId,
    );
    expect(repository.createFieldConflicts).not.toHaveBeenCalled();
  });

  it("the worked example: two devices change the same field to different values — the second is not applied, a conflict is recorded", async () => {
    // Device A (Priya) applies first, uncontested — phone becomes 9876543210, updatedBy: Priya.
    // Device B (Anil) then arrives with a *stale* base_phone (the pre-A value) and a *different*
    // new value — its own edit is not applied; a conflict is recorded instead.
    vi.mocked(identityService.resolveUserId).mockResolvedValue(managerUserId);
    vi.mocked(repository.findCustomerById).mockResolvedValue(
      customerRow({ phone: "9876543210", updatedBy: userId }) as never, // Priya's edit already landed
    );

    const result = await updateCustomer(
      authUserId,
      tenantId,
      customerId,
      patchInput({ base_phone: "9111111111", phone: "9876500000" }), // Anil's stale base + new value
    );

    expect(repository.updateCustomerFields).not.toHaveBeenCalled();
    expect(repository.createFieldConflicts).toHaveBeenCalledWith(tenantId, customerId, [
      {
        field: "phone",
        currentValue: "9876543210",
        currentSetBy: userId, // Priya, the row's own updatedBy
        attemptedValue: "9876500000",
        attemptedSetBy: managerUserId, // Anil, this call's own actor
      },
    ]);
    // The customer's own returned state still reflects the currently-applied (Priya's) value.
    expect(result.phone).toBe("9876543210");
  });

  it("is a silent no-op, not a conflict, when the attempted value already matches current", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(
      customerRow({ phone: "9876543210", updatedBy: userId }) as never,
    );

    await updateCustomer(
      authUserId,
      tenantId,
      customerId,
      patchInput({ base_phone: "9111111111", phone: "9876543210" }),
    );

    expect(repository.updateCustomerFields).not.toHaveBeenCalled();
    expect(repository.createFieldConflicts).not.toHaveBeenCalled();
  });

  it("attributes the current value to the customer's own creator when it has never been edited", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(
      customerRow({ createdBy: userId, updatedBy: null }) as never,
    );

    await updateCustomer(
      authUserId,
      tenantId,
      customerId,
      patchInput({ base_phone: "9111111111", phone: "9876500000" }),
    );

    expect(repository.createFieldConflicts).toHaveBeenCalledWith(
      tenantId,
      customerId,
      expect.arrayContaining([expect.objectContaining({ currentSetBy: userId })]),
    );
  });

  it("rejects a PATCH targeting a nonexistent customer with NOT_FOUND", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(null);

    await expect(
      updateCustomer(authUserId, tenantId, customerId, patchInput({ name: "New Name" })),
    ).rejects.toMatchObject({ status: 404, code: "NOT_FOUND" });
    expect(repository.updateCustomerFields).not.toHaveBeenCalled();
  });

  it("rejects a PATCH that would leave both fields null in the merged result", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(
      customerRow({ name: null }) as never,
    );

    await expect(
      updateCustomer(
        authUserId,
        tenantId,
        customerId,
        patchInput({ base_name: null, name: null, phone: null }),
      ),
    ).rejects.toMatchObject({ status: 422, code: "CUSTOMER_IDENTIFIER_REQUIRED" });
    expect(repository.updateCustomerFields).not.toHaveBeenCalled();
  });

  it("translates a phone unique-constraint violation into PHONE_ALREADY_ASSIGNED", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(customerRow() as never);
    vi.mocked(repository.updateCustomerFields).mockRejectedValue(uniqueConstraintError());

    await expect(
      updateCustomer(authUserId, tenantId, customerId, patchInput({ phone: "1111111111" })),
    ).rejects.toMatchObject({ status: 409, code: "PHONE_ALREADY_ASSIGNED" });
  });
});

describe("listConflicts", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  function conflictRow(overrides: Partial<Record<string, unknown>> = {}) {
    return {
      id: conflictId,
      customerId,
      field: "phone",
      currentValue: "9876543210",
      attemptedValue: "9876500000",
      createdAt: new Date("2026-08-16T00:00:00Z"),
      resolvedAt: null,
      resolvedValue: null,
      resolvedBy: null,
      customer: { name: "Ramesh Kumar", phone: "9876543210" },
      currentSetByUser: { id: userId, displayName: "Priya" },
      attemptedSetByUser: { id: managerUserId, displayName: "Anil" },
      ...overrides,
    };
  }

  it("returns unresolved conflicts, formatted with both actors' display names", async () => {
    vi.mocked(repository.listUnresolvedConflicts).mockResolvedValue([conflictRow()] as never);

    const result = await listConflicts(tenantId, { limit: 50 });

    expect(result.data).toEqual([
      {
        id: conflictId,
        customer_id: customerId,
        customer_name: "Ramesh Kumar",
        field: "phone",
        current_value: "9876543210",
        current_set_by: { id: userId, display_name: "Priya" },
        attempted_value: "9876500000",
        attempted_set_by: { id: managerUserId, display_name: "Anil" },
        created_at: "2026-08-16T00:00:00.000Z",
      },
    ]);
  });
});

describe("resolveConflict", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(managerUserId);
  });

  function conflictRow(overrides: Partial<Record<string, unknown>> = {}) {
    return {
      id: conflictId,
      customerId,
      field: "phone",
      currentValue: "9876543210",
      attemptedValue: "9876500000",
      createdAt: new Date("2026-08-16T00:00:00Z"),
      resolvedAt: null,
      resolvedValue: null,
      resolvedBy: null,
      customer: { name: "Ramesh Kumar", phone: "9876543210" },
      currentSetByUser: { id: userId, displayName: "Priya" },
      attemptedSetByUser: { id: managerUserId, displayName: "Anil" },
      ...overrides,
    };
  }

  it("resolves with one of the two candidate values", async () => {
    vi.mocked(repository.findConflictById).mockResolvedValue(conflictRow() as never);
    vi.mocked(repository.resolveConflict).mockResolvedValue({
      conflict: conflictRow({
        resolvedAt: new Date("2026-08-16T01:00:00Z"),
        resolvedValue: "9876500000",
        resolvedBy: managerUserId,
      }),
      customer: customerRow({ phone: "9876500000" }),
    } as never);

    const result = await resolveConflict(authUserId, tenantId, conflictId, "9876500000");

    expect(repository.resolveConflict).toHaveBeenCalledWith({
      conflictId,
      customerId,
      resolvedValue: "9876500000",
      resolvedBy: managerUserId,
    });
    expect(result.current_value).toBe("9876543210");
  });

  it("rejects a resolved_value matching neither candidate", async () => {
    vi.mocked(repository.findConflictById).mockResolvedValue(conflictRow() as never);

    await expect(
      resolveConflict(authUserId, tenantId, conflictId, "0000000000"),
    ).rejects.toMatchObject({ status: 422, code: "CONFLICT_RESOLUTION_VALUE_INVALID" });
    expect(repository.resolveConflict).not.toHaveBeenCalled();
  });

  it("is an idempotent no-op on an already-resolved conflict", async () => {
    vi.mocked(repository.findConflictById).mockResolvedValue(
      conflictRow({
        resolvedAt: new Date("2026-08-16T01:00:00Z"),
        resolvedValue: "9876500000",
        resolvedBy: managerUserId,
      }) as never,
    );

    const result = await resolveConflict(authUserId, tenantId, conflictId, "9876543210");

    expect(repository.resolveConflict).not.toHaveBeenCalled();
    expect(result.attempted_value).toBe("9876500000");
  });

  it("rejects a nonexistent conflict with NOT_FOUND", async () => {
    vi.mocked(repository.findConflictById).mockResolvedValue(null);

    await expect(
      resolveConflict(authUserId, tenantId, conflictId, "9876500000"),
    ).rejects.toMatchObject({ status: 404, code: "NOT_FOUND" });
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

describe("eraseCustomer", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("nulls name/phone, sets erased_at, and also deactivates a still-active customer", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(customerRow() as never);
    vi.mocked(repository.eraseCustomer).mockResolvedValue(
      customerRow({
        name: null,
        phone: null,
        erasedAt: new Date("2026-08-19T00:00:00Z"),
        deactivatedAt: new Date("2026-08-19T00:00:00Z"),
      }) as never,
    );

    const result = await eraseCustomer(tenantId, customerId);

    // deactivatedAtIfUnset is a real Date, not null, since this customer wasn't deactivated yet.
    expect(repository.eraseCustomer).toHaveBeenCalledWith(customerId, expect.any(Date));
    expect(result.name).toBeNull();
    expect(result.phone).toBeNull();
    expect(result.erased_at).toBe("2026-08-19T00:00:00.000Z");
  });

  it("preserves an already-deactivated customer's own deactivated_at rather than overwriting it", async () => {
    const originalDeactivation = new Date("2026-08-10T00:00:00Z");
    vi.mocked(repository.findCustomerById).mockResolvedValue(
      customerRow({ deactivatedAt: originalDeactivation }) as never,
    );
    vi.mocked(repository.eraseCustomer).mockResolvedValue(
      customerRow({
        name: null,
        phone: null,
        deactivatedAt: originalDeactivation,
        erasedAt: new Date("2026-08-19T00:00:00Z"),
      }) as never,
    );

    await eraseCustomer(tenantId, customerId);

    // null second argument — the repository is told not to touch deactivatedAt at all.
    expect(repository.eraseCustomer).toHaveBeenCalledWith(customerId, null);
  });

  it("is an idempotent no-op on an already-erased customer", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(
      customerRow({ name: null, phone: null, erasedAt: new Date("2026-08-19T00:00:00Z") }) as never,
    );

    await eraseCustomer(tenantId, customerId);

    expect(repository.eraseCustomer).not.toHaveBeenCalled();
  });

  it("rejects a nonexistent customer with NOT_FOUND", async () => {
    vi.mocked(repository.findCustomerById).mockResolvedValue(null);

    await expect(eraseCustomer(tenantId, customerId)).rejects.toMatchObject({
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
