import { randomUUID } from "node:crypto";
import * as identityService from "@/modules/identity/service";
import * as storesService from "@/modules/stores/service";
import { supabaseAdmin } from "@/core/auth/admin-client";
import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import type { UserCursor } from "./repository";
import type { ChangeRoleRequest, InviteUserRequest, Role } from "./schema";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

function formatUser(user: {
  id: string;
  displayName: string;
  deactivatedAt: Date | null;
  createdAt: Date;
  roleAssignments?: { role: string }[];
}) {
  return {
    id: user.id,
    display_name: user.displayName,
    role: user.roleAssignments?.[0]?.role ?? null,
    deactivated_at: user.deactivatedAt?.toISOString() ?? null,
    created_at: user.createdAt.toISOString(),
  };
}

/**
 * The core permission-resolution primitive `core/auth/session.ts`'s `requirePermission` calls on
 * every authorised request — docs/modules/roles-permissions/specification.md §4/§6. Never caches
 * across requests (DR-017): a fresh lookup every time.
 */
export async function resolveActiveRole(
  tenantId: string,
  userId: string,
  storeId: string,
): Promise<Role | null> {
  const role = await repository.findActiveRole(tenantId, userId, storeId);
  return (role as Role | null) ?? null;
}

/**
 * docs/modules/roles-permissions/specification.md#4-api-contract — POST /api/v1/users/invite.
 * Owner-only (enforced by the Route Handler's own `requirePermission` call, not here — see this
 * module's own spec §5 on where the permission gate lives).
 */
export async function inviteUser(authUserId: string, tenantId: string, input: InviteUserRequest) {
  const inviterId = await identityService.resolveUserId(authUserId);
  const storeId = await storesService.getPrimaryStoreId(tenantId);

  const { data, error } = await supabaseAdmin.auth.admin.inviteUserByEmail(input.email);
  if (error) {
    // Supabase Admin's own duplicate-email rejection ("email_exists" as of current supabase-js),
    // translated to a named code rather than surfaced as a raw provider error — the same
    // translation pattern products/service.ts already uses for its own P2002 catch.
    if (error.code === "email_exists" || /already registered/i.test(error.message)) {
      throw new ApiError(
        409,
        "EMAIL_ALREADY_REGISTERED",
        `Email ${input.email} is already registered.`,
      );
    }
    throw error;
  }

  const { user, roleAssignment } = await repository.createInvitedUser({
    id: input.id,
    tenantId,
    authUserId: data.user.id,
    displayName: input.display_name,
    storeId,
    role: input.role,
    createdBy: inviterId,
    roleAssignmentId: randomUUID(),
  });

  return formatUser({ ...user, roleAssignments: [roleAssignment] });
}

/**
 * docs/modules/roles-permissions/specification.md#4-api-contract — PATCH /api/v1/users/{id}/role.
 * Idempotent replay checked before any recompute, the same `findSaleById`-style short-circuit
 * pos/service.ts already established — a retry of the same `id` must never re-revoke a role a
 * moment after this same call already replaced it.
 */
export async function changeRole(
  authUserId: string,
  tenantId: string,
  targetUserId: string,
  input: ChangeRoleRequest,
) {
  const existingAssignment = await repository.findRoleAssignmentById(input.id);
  if (existingAssignment) {
    return {
      id: existingAssignment.id,
      user_id: existingAssignment.userId,
      role: existingAssignment.role,
      created_at: existingAssignment.createdAt.toISOString(),
    };
  }

  const target = await repository.findUserById(tenantId, targetUserId);
  if (!target) {
    throw new ApiError(404, "NOT_FOUND", `User ${targetUserId} not found.`);
  }

  const actingUserId = await identityService.resolveUserId(authUserId);
  const storeId = await storesService.getPrimaryStoreId(tenantId);

  const currentRole = await repository.findActiveRole(tenantId, targetUserId, storeId);
  if (currentRole === "owner" && input.role !== "owner") {
    const ownerCount = await repository.countActiveOwners(tenantId, storeId);
    if (ownerCount <= 1) {
      throw new ApiError(
        409,
        "LAST_OWNER_CANNOT_BE_REMOVED",
        "This would leave the tenant with zero active Owners.",
      );
    }
  }

  const created = await repository.changeRole({
    id: input.id,
    tenantId,
    userId: targetUserId,
    storeId,
    role: input.role,
    assignedBy: actingUserId,
  });

  return {
    id: created.id,
    user_id: created.userId,
    role: created.role,
    created_at: created.createdAt.toISOString(),
  };
}

/**
 * docs/modules/roles-permissions/specification.md#4-api-contract — DELETE /api/v1/users/{id}.
 * No client-generated idempotency key exists for a DELETE with no body — an already-deactivated
 * target is treated as an idempotent replay directly, rather than re-touching `deactivated_at` or
 * writing a second audit entry.
 */
export async function deactivateUser(authUserId: string, tenantId: string, targetUserId: string) {
  const target = await repository.findUserById(tenantId, targetUserId);
  if (!target) {
    throw new ApiError(404, "NOT_FOUND", `User ${targetUserId} not found.`);
  }
  if (target.deactivatedAt) {
    return formatUser(target);
  }

  const actingUserId = await identityService.resolveUserId(authUserId);
  const storeId = await storesService.getPrimaryStoreId(tenantId);

  const currentRole = await repository.findActiveRole(tenantId, targetUserId, storeId);
  if (currentRole === "owner") {
    const ownerCount = await repository.countActiveOwners(tenantId, storeId);
    if (ownerCount <= 1) {
      throw new ApiError(
        409,
        "LAST_OWNER_CANNOT_BE_REMOVED",
        "This would leave the tenant with zero active Owners.",
      );
    }
  }

  const deactivated = await repository.deactivateUser({
    tenantId,
    userId: targetUserId,
    storeId,
    actorUserId: actingUserId,
  });

  return formatUser(deactivated);
}

/**
 * docs/modules/roles-permissions/specification.md#4-api-contract — GET /api/v1/users.
 */
export async function listUsers(tenantId: string, query: { cursor?: string; limit: number }) {
  const storeId = await storesService.getPrimaryStoreId(tenantId);
  const decodedCursor = query.cursor ? decodeCursor(query.cursor) : null;
  const fetched = await repository.listUsers(tenantId, storeId, decodedCursor, query.limit);
  const hasMore = fetched.length > query.limit;
  const rows = hasMore ? fetched.slice(0, query.limit) : fetched;
  const lastRow = rows[rows.length - 1];
  const nextCursor = hasMore && lastRow ? encodeCursor(lastRow) : null;

  return {
    data: rows.map((user) => formatUser(user)),
    next_cursor: nextCursor,
  };
}

function encodeCursor(row: UserCursor): string {
  return Buffer.from(`${row.createdAt.toISOString()}|${row.id}`).toString("base64url");
}

function decodeCursor(cursor: string): UserCursor {
  let createdAtIso: string | undefined;
  let id: string | undefined;
  try {
    [createdAtIso, id] = Buffer.from(cursor, "base64url").toString("utf8").split("|");
  } catch {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }

  const createdAt = createdAtIso ? new Date(createdAtIso) : undefined;
  if (!createdAt || Number.isNaN(createdAt.getTime()) || !id) {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }

  return { createdAt, id };
}
