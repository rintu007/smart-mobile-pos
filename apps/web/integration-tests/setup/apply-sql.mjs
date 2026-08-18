// Applies integration-tests/setup/auth-stub.sql, then every supabase/sql/*.sql RLS policy file, in
// numeric order, against DATABASE_URL — plain `pg` (simple query protocol, so a file's multiple
// `;`-separated statements run in one call, unlike Prisma's own $executeRawUnsafe, which uses
// prepared statements and rejects multi-statement strings). Sprint 40 (backlog.md M4 item 5). Run
// once, before the migrations built by `prisma migrate deploy` are handed off to the actual
// cross-tenant isolation suite (vitest.integration.config.ts).
import { readFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { Client } from "pg";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, "..", "..", "..", "..");

async function main() {
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();

  const authStub = readFileSync(join(__dirname, "auth-stub.sql"), "utf8");
  await client.query(authStub);
  console.log("applied auth-stub.sql");

  const rlsDir = join(repoRoot, "supabase", "sql");
  const files = readdirSync(rlsDir)
    .filter((f) => f.endsWith(".sql"))
    .sort();

  for (const file of files) {
    const sql = readFileSync(join(rlsDir, file), "utf8");
    await client.query(sql);
    console.log("applied", file);
  }

  await client.end();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
