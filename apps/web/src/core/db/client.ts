import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

// Singleton Prisma client, per docs/08-folder-structure/backend-structure.md — `core/db` is the
// only place this is instantiated; every module's `repository.ts` imports it from here, never
// constructs its own client. This file must never be imported from client-side code — enforced
// structurally at Phase 15 (docs/12-security/secrets-management.md §3), not yet wired into CI
// until Sprint 01's `import-boundaries` job exists.

// Prisma 7 requires an explicit driver adapter — DATABASE_URL (the pooled Supavisor connection,
// docs/11-api/rate-limiting.md §3) is the correct one for runtime request traffic; DIRECT_URL is
// reserved for the Prisma CLI's own migrations, configured separately in prisma.config.ts.
const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    adapter,
    log: process.env.NODE_ENV === "development" ? ["warn", "error"] : ["error"],
  });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}
