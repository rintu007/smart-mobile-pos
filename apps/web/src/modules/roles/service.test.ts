import { describe, expect, it, vi, beforeEach } from "vitest";
import * as identityService from "@/modules/identity/service";
import * as storesService from "@/modules/stores/service";
import { supabaseAdmin } from "@/core/auth/admin-client";
import * as repository from "./repository";
import { changeRole, deactivateUser, inviteUser, listUsers, resolveActiveRole } from "./service";
import type { ChangeRoleRequest, InviteUserRequest } from "./schema";

vi.mock("./repository");
vi.mock("@/modules/identity/service");
vi.mock("@/modules/stores/service");
vi.mock("@/core/auth/admin-client", () => ({
  supabaseAdmin: { auth: { admin: { inviteUserByEmail: vi.fn() } } },
}));

const authUserId = "11111111-1111-4111-8111-111111111111";
const tenantId = "22222222-2222-4222-8222-222222222222";
const actingUserId = "33333333-3333-4333-8333-333333333333";
const storeId = "55555555-5555-4555-8555-555555555555";
const targetUserId = "66666666-6666-4666-8666-666666666666";
const invitedAuthUserId = "77777777-7777-4777-8777-777777777777";

describe("resolveActiveRole", () => {
  beforeEach(() => vi.resetAllMocks());

  it("returns null when the repository finds no active assignment", async () => {
    vi.mocked(repository.findActiveRole).mockResolvedValue(null);
    expect(await resolveActiveRole(tenantId, targetUserId, storeId)).toBeNull();
  });

  it("returns the resolved role", async () => {
    vi.mocked(repository.findActiveRole).mockResolvedValue("manager");
    expect(await resolveActiveRole(tenantId, targetUserId, storeId)).toBe("manager");
  });
});

describe("inviteUser", () => {
  const input: InviteUserRequest = {
    id: "88888888-8888-4888-8888-888888888888",
    email: "cashier@example.com",
    display_name: "New Cashier",
    role: "cashier",
  };

  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(actingUserId);
    vi.mocked(storesService.getPrimaryStoreId).mockResolvedValue(storeId);
  });

  it("creates the Auth identity, then the user + role assignment", async () => {
    vi.mocked(supabaseAdmin.auth.admin.inviteUserByEmail).mockResolvedValue({
      data: { user: { id: invitedAuthUserId } },
      error: null,
    } as never);
    vi.mocked(repository.createInvitedUser).mockResolvedValue({
      user: {
        id: input.id,
        displayName: input.display_name,
        deactivatedAt: null,
        createdAt: new Date("2026-08-14T00:00:00Z"),
      },
      roleAssignment: { role: "cashier" },
    } as never);

    const result = await inviteUser(authUserId, tenantId, input);

    expect(supabaseAdmin.auth.admin.inviteUserByEmail).toHaveBeenCalledWith(input.email);
    expect(repository.createInvitedUser).toHaveBeenCalledWith(
      expect.objectContaining({
        id: input.id,
        tenantId,
        authUserId: invitedAuthUserId,
        displayName: input.display_name,
        storeId,
        role: input.role,
        createdBy: actingUserId,
      }),
    );
    expect(result).toEqual({
      id: input.id,
      display_name: input.display_name,
      role: "cashier",
      deactivated_at: null,
      created_at: "2026-08-14T00:00:00.000Z",
    });
  });

  it("translates a duplicate-email rejection into EMAIL_ALREADY_REGISTERED", async () => {
    vi.mocked(supabaseAdmin.auth.admin.inviteUserByEmail).mockResolvedValue({
      data: null,
      error: { code: "email_exists", message: "A user with this email has already been registered" },
    } as never);

    await expect(inviteUser(authUserId, tenantId, input)).rejects.toMatchObject({
      status: 409,
      code: "EMAIL_ALREADY_REGISTERED",
    });
    expect(repository.createInvitedUser).not.toHaveBeenCalled();
  });
});

describe("changeRole", () => {
  const input: ChangeRoleRequest = {
    id: "99999999-9999-4999-8999-999999999999",
    role: "manager",
  };

  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(actingUserId);
    vi.mocked(storesService.getPrimaryStoreId).mockResolvedValue(storeId);
  });

  it("returns the existing assignment unchanged on an idempotent replay", async () => {
    vi.mocked(repository.findRoleAssignmentById).mockResolvedValue({
      id: input.id,
      userId: targetUserId,
      role: "manager",
      createdAt: new Date("2026-08-14T00:00:00Z"),
    } as never);

    const result = await changeRole(authUserId, tenantId, targetUserId, input);

    expect(result).toEqual({
      id: input.id,
      user_id: targetUserId,
      role: "manager",
      created_at: "2026-08-14T00:00:00.000Z",
    });
    expect(repository.findUserById).not.toHaveBeenCalled();
    expect(repository.changeRole).not.toHaveBeenCalled();
  });

  it("rejects an unknown target user with NOT_FOUND", async () => {
    vi.mocked(repository.findRoleAssignmentById).mockResolvedValue(null);
    vi.mocked(repository.findUserById).mockResolvedValue(null as never);

    await expect(changeRole(authUserId, tenantId, targetUserId, input)).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
    expect(repository.changeRole).not.toHaveBeenCalled();
  });

  it("rejects demoting the tenant's last active Owner with LAST_OWNER_CANNOT_BE_REMOVED", async () => {
    vi.mocked(repository.findRoleAssignmentById).mockResolvedValue(null);
    vi.mocked(repository.findUserById).mockResolvedValue({ id: targetUserId } as never);
    vi.mocked(repository.findActiveRole).mockResolvedValue("owner");
    vi.mocked(repository.countActiveOwners).mockResolvedValue(1);

    await expect(changeRole(authUserId, tenantId, targetUserId, input)).rejects.toMatchObject({
      status: 409,
      code: "LAST_OWNER_CANNOT_BE_REMOVED",
    });
    expect(repository.changeRole).not.toHaveBeenCalled();
  });

  it("allows demoting an Owner when another active Owner remains", async () => {
    vi.mocked(repository.findRoleAssignmentById).mockResolvedValue(null);
    vi.mocked(repository.findUserById).mockResolvedValue({ id: targetUserId } as never);
    vi.mocked(repository.findActiveRole).mockResolvedValue("owner");
    vi.mocked(repository.countActiveOwners).mockResolvedValue(2);
    vi.mocked(repository.changeRole).mockResolvedValue({
      id: input.id,
      userId: targetUserId,
      role: "manager",
      createdAt: new Date("2026-08-14T00:00:00Z"),
    } as never);

    const result = await changeRole(authUserId, tenantId, targetUserId, input);

    expect(repository.changeRole).toHaveBeenCalledWith({
      id: input.id,
      tenantId,
      userId: targetUserId,
      storeId,
      role: "manager",
      assignedBy: actingUserId,
    });
    expect(result.role).toBe("manager");
  });
});

describe("deactivateUser", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(actingUserId);
    vi.mocked(storesService.getPrimaryStoreId).mockResolvedValue(storeId);
  });

  it("rejects an unknown target user with NOT_FOUND", async () => {
    vi.mocked(repository.findUserById).mockResolvedValue(null as never);

    await expect(deactivateUser(authUserId, tenantId, targetUserId)).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
  });

  it("returns the user unchanged on an idempotent replay (already deactivated)", async () => {
    const alreadyDeactivated = {
      id: targetUserId,
      displayName: "Cashier",
      deactivatedAt: new Date("2026-08-13T00:00:00Z"),
      createdAt: new Date("2026-08-01T00:00:00Z"),
    };
    vi.mocked(repository.findUserById).mockResolvedValue(alreadyDeactivated as never);

    const result = await deactivateUser(authUserId, tenantId, targetUserId);

    expect(result.deactivated_at).toBe("2026-08-13T00:00:00.000Z");
    expect(repository.deactivateUser).not.toHaveBeenCalled();
  });

  it("rejects deactivating the tenant's last active Owner with LAST_OWNER_CANNOT_BE_REMOVED", async () => {
    vi.mocked(repository.findUserById).mockResolvedValue({
      id: targetUserId,
      deactivatedAt: null,
    } as never);
    vi.mocked(repository.findActiveRole).mockResolvedValue("owner");
    vi.mocked(repository.countActiveOwners).mockResolvedValue(1);

    await expect(deactivateUser(authUserId, tenantId, targetUserId)).rejects.toMatchObject({
      status: 409,
      code: "LAST_OWNER_CANNOT_BE_REMOVED",
    });
    expect(repository.deactivateUser).not.toHaveBeenCalled();
  });

  it("deactivates a non-last-Owner user", async () => {
    vi.mocked(repository.findUserById).mockResolvedValue({
      id: targetUserId,
      deactivatedAt: null,
    } as never);
    vi.mocked(repository.findActiveRole).mockResolvedValue("cashier");
    vi.mocked(repository.deactivateUser).mockResolvedValue({
      id: targetUserId,
      displayName: "Cashier",
      deactivatedAt: new Date("2026-08-14T00:00:00Z"),
      createdAt: new Date("2026-08-01T00:00:00Z"),
    } as never);

    const result = await deactivateUser(authUserId, tenantId, targetUserId);

    expect(repository.countActiveOwners).not.toHaveBeenCalled();
    expect(result.deactivated_at).toBe("2026-08-14T00:00:00.000Z");
  });
});

describe("listUsers", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(storesService.getPrimaryStoreId).mockResolvedValue(storeId);
  });

  const user = (id: string, createdAt: Date, role: string | null) => ({
    id,
    displayName: "User",
    deactivatedAt: null,
    createdAt,
    roleAssignments: role ? [{ role }] : [],
  });

  it("returns a non-null next_cursor when more rows exist beyond the requested limit", async () => {
    const rows = [
      user("u1", new Date("2026-08-01T00:00:00Z"), "owner"),
      user("u2", new Date("2026-08-02T00:00:00Z"), "cashier"),
      user("u3", new Date("2026-08-03T00:00:00Z"), null),
    ];
    vi.mocked(repository.listUsers).mockResolvedValue(rows as never);

    const result = await listUsers(tenantId, { limit: 2 });

    expect(result.data).toHaveLength(2);
    expect(result.data[0]?.role).toBe("owner");
    expect(result.data[1]?.role).toBe("cashier");
    expect(result.next_cursor).not.toBeNull();
  });

  it("returns null role for a user with no active assignment", async () => {
    vi.mocked(repository.listUsers).mockResolvedValue([
      user("u1", new Date("2026-08-01T00:00:00Z"), null),
    ] as never);

    const result = await listUsers(tenantId, { limit: 50 });

    expect(result.data[0]?.role).toBeNull();
    expect(result.next_cursor).toBeNull();
  });

  it("rejects a malformed cursor with VALIDATION_FAILED rather than crashing", async () => {
    await expect(listUsers(tenantId, { cursor: "not-a-real-cursor!!", limit: 50 })).rejects.toMatchObject({
      status: 422,
      code: "VALIDATION_FAILED",
    });
  });
});
