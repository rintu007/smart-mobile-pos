import { PrismaClient } from "@prisma/client";
import { createTestPrismaClient } from "./setup/create-test-prisma-client";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { seedTenant, type SeededTenant } from "./setup/seed-tenant";

/**
 * The CI-enforced cross-tenant isolation suite — backlog.md M4 item 5,
 * docs/12-security/tenant-isolation.md §2/§3, docs/07-database/tenancy-model.md §5. Runs against a
 * real, RLS-enabled Postgres connection (a `services:` container in `pr.yml`'s `fast-integration`
 * job — see vitest.integration.config.ts's own doc comment for why this is a separate suite from
 * the fully-mocked unit tests), authenticated as a real tenant-scoped role via
 * `SET LOCAL ROLE authenticated` + `SET LOCAL request.jwt.claims`, exactly the mechanism a real
 * Supabase-issued JWT drives in production (integration-tests/setup/auth-stub.sql explains the one
 * function this stubs and why it's faithful). This is deliberately independent of the API layer
 * being correct (tenant-isolation.md §1) — it hits the database directly, the same as an attacker
 * who obtained direct Postgres access somehow would, never going through `apps/web/src`'s own
 * service-layer code at all.
 *
 * **20 of the 22 originally-listed tables are covered here** — `product_variants`/`batches`/
 * `idempotency_keys`/`sync_rejections` don't exist in the built schema at all (V2+/V4 stubs, or
 * never built; schema.prisma's own header comment). `devices` was the fifth, until Sprint 55 built
 * it — added here in the same pass, the same "parent-join" shape as `sale_line_items`/
 * `sale_payments`/`return_line_items`, just via `users` instead of `sales`/`returns`. Two real
 * tables the original checklist never listed (`invoice_sequences`, `customer_field_conflicts`,
 * added Sprint 24/35 after that doc was written) are included here too — found and corrected in
 * the same pass, per this project's own established practice.
 *
 * **Store-level second-dimension scoping (tenancy-model.md §4's "overlay" category) is
 * deliberately not tested here** — no such second RLS policy dimension exists in any of
 * `supabase/sql/*.sql` today (tenancy-model.md §4 itself frames this as "close to formality" in
 * V1's one-store-per-tenant reality); testing it would legitimately fail not because of a bug but
 * because it was never built. Named, not silently skipped — tracked as a real, deferred gap.
 */

type Category = "direct" | "parent-join" | "boundary";

interface TableSpec {
  table: string;
  category: Category;
  /** The column holding the row's own identifier — `id` for every table except `shop_settings`,
   * whose primary key is `tenant_id` itself. */
  idColumn: "id" | "tenant_id";
  idFrom: (tenant: SeededTenant) => string;
}

const TABLES: TableSpec[] = [
  { table: "tenants", category: "boundary", idColumn: "id", idFrom: (t) => t.tenantId },
  { table: "stores", category: "direct", idColumn: "id", idFrom: (t) => t.storeId },
  { table: "users", category: "direct", idColumn: "id", idFrom: (t) => t.userId },
  { table: "user_store_roles", category: "direct", idColumn: "id", idFrom: (t) => t.userStoreRoleId },
  { table: "categories", category: "direct", idColumn: "id", idFrom: (t) => t.categoryId },
  { table: "units", category: "direct", idColumn: "id", idFrom: (t) => t.unitId },
  { table: "products", category: "direct", idColumn: "id", idFrom: (t) => t.productId },
  { table: "customers", category: "direct", idColumn: "id", idFrom: (t) => t.customerId },
  { table: "trading_days", category: "direct", idColumn: "id", idFrom: (t) => t.tradingDayId },
  { table: "sales", category: "direct", idColumn: "id", idFrom: (t) => t.saleId },
  { table: "returns", category: "direct", idColumn: "id", idFrom: (t) => t.returnId },
  { table: "shop_settings", category: "direct", idColumn: "tenant_id", idFrom: (t) => t.tenantId },
  { table: "invoice_sequences", category: "direct", idColumn: "id", idFrom: (t) => t.invoiceSequenceId },
  { table: "stock_movements", category: "direct", idColumn: "id", idFrom: (t) => t.stockMovementId },
  { table: "audit_log", category: "direct", idColumn: "id", idFrom: (t) => t.auditLogId },
  {
    table: "customer_field_conflicts",
    category: "direct",
    idColumn: "id",
    idFrom: (t) => t.customerFieldConflictId,
  },
  { table: "sale_line_items", category: "parent-join", idColumn: "id", idFrom: (t) => t.saleLineItemId },
  { table: "sale_payments", category: "parent-join", idColumn: "id", idFrom: (t) => t.salePaymentId },
  {
    table: "return_line_items",
    category: "parent-join",
    idColumn: "id",
    idFrom: (t) => t.returnLineItemId,
  },
  // Sprint 55 — `devices` (docs/07-database/schema-server.md) joins via `user_id` to `users`
  // rather than `sale_id`/`return_id` to `sales`/`returns`, but the test shape below doesn't care
  // which parent a row joins through, only that RLS enforces one — no new category needed.
  { table: "devices", category: "parent-join", idColumn: "id", idFrom: (t) => t.deviceId },
];

let prisma: PrismaClient;
let tenantA: SeededTenant;
let tenantB: SeededTenant;

beforeAll(async () => {
  prisma = createTestPrismaClient();
  tenantA = await seedTenant(prisma, "A");
  tenantB = await seedTenant(prisma, "B");
}, 30_000);

afterAll(async () => {
  await prisma.$disconnect();
});

function claimsFor(tenantId: string, userId: string) {
  return JSON.stringify({ sub: userId, role: "authenticated", tenant_id: tenantId }).replace(/'/g, "''");
}

/** Runs `SELECT`/`UPDATE`/`DELETE` by id, authenticated as `asTenant`, against `targetId` — always
 * rolled back, so a real leak (a bug this suite exists to catch) never actually mutates the
 * fixture for a later assertion in the same run. */
/** `includeWrites: false` skips the UPDATE/DELETE attempts — used only by the positive control,
 * where the target row is genuinely visible/writable per RLS but may have real child rows (an
 * ordinary FK `RESTRICT`/`NO ACTION` constraint, nothing to do with tenant isolation) that would
 * make a same-tenant DELETE fail for an unrelated reason and abort the transaction before the
 * SELECT assertion this test actually cares about is ever reached. */
async function attempt(
  spec: TableSpec,
  asTenant: SeededTenant,
  targetId: string,
  includeWrites = true,
) {
  const claims = claimsFor(asTenant.tenantId, asTenant.userId);
  const result = { selectCount: -1, updateCount: -1, deleteCount: -1 };

  class RollbackSentinel extends Error {}
  try {
    await prisma.$transaction(async (tx) => {
      await tx.$executeRawUnsafe(`SET LOCAL ROLE authenticated`);
      await tx.$executeRawUnsafe(`SET LOCAL request.jwt.claims = '${claims}'`);

      const selectRows = await tx.$queryRawUnsafe<unknown[]>(
        `SELECT 1 FROM ${spec.table} WHERE ${spec.idColumn} = $1::uuid`,
        targetId,
      );
      result.selectCount = selectRows.length;

      if (includeWrites) {
        result.updateCount = await tx.$executeRawUnsafe(
          `UPDATE ${spec.table} SET ${spec.idColumn} = ${spec.idColumn} WHERE ${spec.idColumn} = $1::uuid`,
          targetId,
        );

        result.deleteCount = await tx.$executeRawUnsafe(
          `DELETE FROM ${spec.table} WHERE ${spec.idColumn} = $1::uuid`,
          targetId,
        );
      }

      throw new RollbackSentinel();
    });
  } catch (error) {
    if (!(error instanceof RollbackSentinel)) throw error;
  }
  return result;
}

describe("cross-tenant isolation (backlog.md M4 item 5)", () => {
  for (const spec of TABLES) {
    describe(`${spec.table} (${spec.category})`, () => {
      it("positive control: tenant A can see its own row (proves the harness itself works)", async () => {
        const ownId = spec.idFrom(tenantA);
        const result = await attempt(spec, tenantA, ownId, false);
        expect(result.selectCount).toBe(1);
      });

      it("tenant A cannot read tenant B's row by id", async () => {
        const targetId = spec.idFrom(tenantB);
        const result = await attempt(spec, tenantA, targetId);
        expect(result.selectCount).toBe(0);
      });

      it("tenant A cannot update tenant B's row by id", async () => {
        const targetId = spec.idFrom(tenantB);
        const result = await attempt(spec, tenantA, targetId);
        expect(result.updateCount).toBe(0);
      });

      it("tenant A cannot delete tenant B's row by id", async () => {
        const targetId = spec.idFrom(tenantB);
        const result = await attempt(spec, tenantA, targetId);
        expect(result.deleteCount).toBe(0);
      });
    });
  }
});
