import { prisma } from "@/core/db/client";
import type { OnboardingRequest } from "./schema";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

export function findUserByAuthId(authUserId: string) {
  return prisma.user.findUnique({ where: { authUserId } });
}

export async function createOnboarding(input: OnboardingRequest & { authUserId: string }) {
  // Upsert-on-id (not .create) is what makes a same-IDs retry idempotent per
  // docs/11-api/api-principles.md §3: ON CONFLICT (id) DO NOTHING, effectively — an empty `update`
  // means a retry returns the row exactly as first created, never re-applying the write.
  //
  // Order is tenant, then user, then store -- NOT tenant/store/user. Only tenants.created_by and
  // users.tenant_id are the deferred circular pair (docs/18-implementation/implementation-log.md);
  // stores.created_by -> users.id is an ordinary, non-deferred FK, so `user` must exist before
  // `store` is inserted. Found by actually running this against the live database, not by
  // inspection -- the store insert failed immediately with stores_created_by_fkey the first time.
  const [tenant, user, store] = await prisma.$transaction([
    prisma.tenant.upsert({
      where: { id: input.tenant_id },
      create: { id: input.tenant_id, name: input.tenant_name, createdBy: input.user_id },
      update: {},
    }),
    prisma.user.upsert({
      where: { id: input.user_id },
      create: {
        id: input.user_id,
        tenantId: input.tenant_id,
        authUserId: input.authUserId,
        displayName: input.display_name,
        createdBy: input.user_id,
      },
      update: {},
    }),
    prisma.store.upsert({
      where: { id: input.store_id },
      create: {
        id: input.store_id,
        tenantId: input.tenant_id,
        name: input.store_name,
        address: input.store_address,
        createdBy: input.user_id,
      },
      update: {},
    }),
  ]);

  return { tenant, store, user };
}
