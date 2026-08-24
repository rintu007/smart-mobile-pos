import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

/**
 * Prisma 7 requires an explicit driver adapter (core/db/client.ts's own production instantiation
 * is the canonical example) — every integration-test file that previously called bare
 * `new PrismaClient()` (relying on DATABASE_URL through schema.prisma's now-removed `datasource.url`)
 * needs the same adapter wiring. Centralised here rather than duplicated across all 8 call sites.
 */
export function createTestPrismaClient(): PrismaClient {
  const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
  return new PrismaClient({ adapter });
}
