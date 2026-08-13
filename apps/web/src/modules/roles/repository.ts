import { randomUUID } from "node:crypto";
import { prisma } from "@/core/db/client";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

// docs/modules/roles-permissions/specification.md §2 — a deactivated user has no active
// permission regardless of what user_store_roles still says; joining against
// users.deactivated_at IS NULL here means the caller (resolveActiveRole) needs no second check.
export async function findActiveRole(
  tenantId: string,
  userId: string,
  storeId: string,
): Promise<string | null> {
  const assignment = await prisma.userStoreRole.findFirst({
    where: {
      tenantId,
      userId,
      storeId,
      revokedAt: null,
      user: { deactivatedAt: null },
    },
  });
  return assignment?.role ?? null;
}

export function countActiveOwners(tenantId: string, storeId: string) {
  return prisma.userStoreRole.count({
    where: {
      tenantId,
      storeId,
      role: "owner",
      revokedAt: null,
      user: { deactivatedAt: null },
    },
  });
}

export function findUserById(tenantId: string, id: string) {
  return prisma.user.findFirst({ where: { id, tenantId } });
}

export function findRoleAssignmentById(id: string) {
  return prisma.userStoreRole.findUnique({ where: { id } });
}

export interface CreateInvitedUserInput {
  id: string;
  tenantId: string;
  authUserId: string;
  displayName: string;
  storeId: string;
  role: string;
  createdBy: string;
  roleAssignmentId: string;
}

// docs/modules/roles-permissions/specification.md §4 — POST /users/invite. Creates the users row
// (against the Auth identity's real, already-known auth_user_id — §1's dated clarification) and
// its initial user_store_roles row, plus the two audit-log entries audit-model.md §1 names
// ("User created", "Role assigned"), all in one transaction. Each audit row reuses its own
// triggering row's id — a 1:1 relationship, the same pattern stock_movements already established.
export function createInvitedUser(input: CreateInvitedUserInput) {
  return prisma.$transaction(async (tx) => {
    const user = await tx.user.upsert({
      where: { id: input.id },
      create: {
        id: input.id,
        tenantId: input.tenantId,
        authUserId: input.authUserId,
        displayName: input.displayName,
        createdBy: input.createdBy,
      },
      update: {},
    });

    const roleAssignment = await tx.userStoreRole.upsert({
      where: { id: input.roleAssignmentId },
      create: {
        id: input.roleAssignmentId,
        tenantId: input.tenantId,
        userId: user.id,
        storeId: input.storeId,
        role: input.role,
        assignedBy: input.createdBy,
      },
      update: {},
    });

    await tx.auditLog.create({
      data: {
        id: input.id,
        tenantId: input.tenantId,
        storeId: input.storeId,
        actorUserId: input.createdBy,
        action: "user.created",
        entityType: "user",
        entityId: user.id,
        afterState: { id: user.id, display_name: user.displayName },
      },
    });

    await tx.auditLog.create({
      data: {
        id: input.roleAssignmentId,
        tenantId: input.tenantId,
        storeId: input.storeId,
        actorUserId: input.createdBy,
        action: "user_store_role.assigned",
        entityType: "user_store_role",
        entityId: roleAssignment.id,
        afterState: { user_id: user.id, role: roleAssignment.role },
      },
    });

    return { user, roleAssignment };
  });
}

export interface ChangeRoleInput {
  id: string;
  tenantId: string;
  userId: string;
  storeId: string;
  role: string;
  assignedBy: string;
}

// docs/modules/roles-permissions/specification.md §2 — a role assignment is never edited in
// place: revokes the prior active row and creates a new one, both in the same transaction, plus
// the "Role assigned or revoked" audit entry (audit-model.md §1).
export function changeRole(input: ChangeRoleInput) {
  return prisma.$transaction(async (tx) => {
    const current = await tx.userStoreRole.findFirst({
      where: { tenantId: input.tenantId, userId: input.userId, storeId: input.storeId, revokedAt: null },
    });

    if (current) {
      await tx.userStoreRole.update({ where: { id: current.id }, data: { revokedAt: new Date() } });
    }

    const created = await tx.userStoreRole.create({
      data: {
        id: input.id,
        tenantId: input.tenantId,
        userId: input.userId,
        storeId: input.storeId,
        role: input.role,
        assignedBy: input.assignedBy,
      },
    });

    await tx.auditLog.create({
      data: {
        id: input.id,
        tenantId: input.tenantId,
        storeId: input.storeId,
        actorUserId: input.assignedBy,
        action: "user_store_role.assigned",
        entityType: "user_store_role",
        entityId: created.id,
        // Omitted (not passed as an explicit `null`) when there's no prior assignment — a fresh
        // role grant is a creation event, matching pos/repository.ts's own "no beforeState" case.
        ...(current ? { beforeState: { role: current.role } } : {}),
        afterState: { user_id: input.userId, role: created.role },
      },
    });

    return created;
  });
}

export interface DeactivateUserInput {
  tenantId: string;
  userId: string;
  storeId: string;
  actorUserId: string;
}

// docs/modules/roles-permissions/specification.md §2 — Tier 1 soft delete (ADR-0009), never a
// hard delete; no change to user_store_roles rows themselves (role resolution already excludes a
// deactivated user's rows, §2). Only ever called once per real deactivation — service.ts's own
// already-deactivated short-circuit means this never runs twice for the same user, so the audit
// row's id can be freshly generated here without an idempotency concern.
export function deactivateUser(input: DeactivateUserInput) {
  return prisma.$transaction(async (tx) => {
    const user = await tx.user.update({
      where: { id: input.userId },
      data: { deactivatedAt: new Date() },
    });

    await tx.auditLog.create({
      data: {
        id: randomUUID(),
        tenantId: input.tenantId,
        storeId: input.storeId,
        actorUserId: input.actorUserId,
        action: "user.deactivated",
        entityType: "user",
        entityId: user.id,
        afterState: { id: user.id, deactivated_at: user.deactivatedAt },
      },
    });

    return user;
  });
}

export interface UserCursor {
  createdAt: Date;
  id: string;
}

// (created_at, id) cursor — Tier 2, `users` has no updated_at. Each user's current active role at
// this store (if any) comes along via a filtered relation include, not a second round-trip query.
export function listUsers(
  tenantId: string,
  storeId: string,
  cursor: UserCursor | null,
  limit: number,
) {
  return prisma.user.findMany({
    where: {
      tenantId,
      ...(cursor
        ? {
            OR: [
              { createdAt: { gt: cursor.createdAt } },
              { createdAt: cursor.createdAt, id: { gt: cursor.id } },
            ],
          }
        : {}),
    },
    include: {
      roleAssignments: { where: { storeId, revokedAt: null } },
    },
    orderBy: [{ createdAt: "asc" }, { id: "asc" }],
    take: limit + 1,
  });
}
