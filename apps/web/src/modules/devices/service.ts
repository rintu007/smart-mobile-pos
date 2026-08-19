import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";

function formatDevice(device: {
  id: string;
  clientDeviceId: string;
  lastSeenAt: Date | null;
  revokedAt: Date | null;
  revokedBy: string | null;
  createdAt: Date;
}) {
  return {
    id: device.id,
    client_device_id: device.clientDeviceId,
    last_seen_at: device.lastSeenAt?.toISOString() ?? null,
    revoked_at: device.revokedAt?.toISOString() ?? null,
    revoked_by: device.revokedBy,
    created_at: device.createdAt.toISOString(),
  };
}

/**
 * docs/11-api/endpoints/identity.md#devices — POST /api/v1/auth/register-device. "Any
 * authenticated user (self only)" — `userId` is always the caller's own resolved id, never a
 * value the request body could name someone else's device against.
 */
export async function registerDevice(userId: string, clientDeviceId: string) {
  const device = await repository.registerDevice(userId, clientDeviceId);
  return formatDevice(device);
}

/**
 * docs/11-api/endpoints/identity.md#devices — GET /api/v1/devices (Owner only). The
 * device-revocation UI list.
 */
export async function listDevices(tenantId: string) {
  const devices = await repository.listDevicesForTenant(tenantId);
  return devices.map(formatDevice);
}

/**
 * docs/11-api/endpoints/identity.md#devices — PATCH /api/v1/devices/{id}/revoke (Owner only).
 * Idempotent on an already-revoked device (the same "return the existing terminal state rather
 * than error" shape `customers/service.ts`'s `eraseCustomer` already established) — irreversible
 * either way, per authentication.md §5: a revoked device never un-revokes, it re-registers as a
 * new one instead.
 */
export async function revokeDevice(tenantId: string, id: string, revokedByUserId: string) {
  const existing = await repository.findByIdForTenant(tenantId, id);
  if (!existing) {
    throw new ApiError(404, "NOT_FOUND", `Device ${id} not found.`);
  }
  if (existing.revokedAt) {
    return formatDevice(existing);
  }

  const revoked = await repository.revokeDevice(id, revokedByUserId);
  return formatDevice(revoked);
}

/**
 * docs/12-security/authorisation-model.md §2's step 2, docs/11-api/authentication.md §4 — called
 * from `core/auth/session.ts`'s `requireSession`, on every authenticated request. Fail-closed
 * throughout (DR-017): no `X-Device-Id` header, no matching row, or a matching-but-revoked row all
 * throw the same `401 DEVICE_REVOKED` — the client's own handling is identical either way (force a
 * local sign-out, never touch the unsynced sales queue, authentication.md §5), so this doesn't
 * distinguish "never registered" from "since revoked" with a different code.
 */
export async function assertDeviceUsable(userId: string, clientDeviceId: string | null) {
  if (!clientDeviceId) {
    throw new ApiError(401, "DEVICE_REVOKED", "No device id presented.");
  }

  const device = await repository.findByUserAndClientDeviceId(userId, clientDeviceId);
  if (!device || device.revokedAt) {
    throw new ApiError(401, "DEVICE_REVOKED", "This device is not registered or has been revoked.");
  }
}
