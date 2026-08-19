import { randomUUID } from "node:crypto";
import { prisma } from "@/core/db/client";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.
// `devices` has no direct `tenant_id` column (docs/07-database/schema-server.md's own design,
// "Tenant scoping: tenant-scoped (via `user_id`)") — every tenant-scoped lookup here joins through
// `user.tenantId`, the same defence-in-depth-at-the-query-layer pattern every other module already
// applies even though RLS (supabase/sql/019_rls_devices.sql) enforces the same boundary again.

export function findByUserAndClientDeviceId(userId: string, clientDeviceId: string) {
  return prisma.device.findUnique({
    where: { userId_clientDeviceId: { userId, clientDeviceId } },
  });
}

// docs/11-api/endpoints/identity.md#devices — "a second call with the same `client_device_id`
// updates `last_seen_at` rather than creating a duplicate row." `id` is server-generated
// (`randomUUID()`), matching `InvoiceSequence`'s own precedent — this row is never created by an
// offline client write needing ADR-0007's idempotency-by-client-id mechanism for the primary key
// itself; `client_device_id` already serves that role as the natural dedup key.
export function registerDevice(userId: string, clientDeviceId: string) {
  const now = new Date();
  return prisma.device.upsert({
    where: { userId_clientDeviceId: { userId, clientDeviceId } },
    create: {
      id: randomUUID(),
      userId,
      clientDeviceId,
      lastSeenAt: now,
      createdBy: userId,
    },
    update: { lastSeenAt: now },
  });
}

export function listDevicesForTenant(tenantId: string) {
  return prisma.device.findMany({
    where: { user: { tenantId } },
    orderBy: { createdAt: "desc" },
  });
}

export function findByIdForTenant(tenantId: string, id: string) {
  return prisma.device.findFirst({
    where: { id, user: { tenantId } },
  });
}

export function revokeDevice(id: string, revokedBy: string) {
  return prisma.device.update({
    where: { id },
    data: { revokedAt: new Date(), revokedBy },
  });
}
