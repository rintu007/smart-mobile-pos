import { PrismaClient } from "@prisma/client";

// Singleton Prisma client, per docs/08-folder-structure/backend-structure.md — `core/db` is the
// only place this is instantiated; every module's `repository.ts` imports it from here, never
// constructs its own client. This file must never be imported from client-side code — enforced
// structurally at Phase 15 (docs/12-security/secrets-management.md §3), not yet wired into CI
// until Sprint 01's `import-boundaries` job exists.

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === "development" ? ["warn", "error"] : ["error"],
  });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}
