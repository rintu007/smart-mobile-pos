-- Hand-edited, not Prisma-generated as-is: fixes the 20260801050159_init migration's mistaken use
-- of `ON DELETE RESTRICT` on the two circular-bootstrapping FKs. Postgres does not allow a
-- `RESTRICT` constraint to actually be deferred (only `NO ACTION` supports it), even when marked
-- `DEFERRABLE INITIALLY DEFERRED` — found when a transactional hard-delete of both rows failed
-- immediately instead of deferring to commit. `tenants_created_by_fkey` isn't modelled in
-- schema.prisma (by design, see its comment there), so Prisma's diff dropped it without
-- recreating it; both re-adds below restore the original DEFERRABLE INITIALLY DEFERRED semantics
-- with the corrected ON DELETE action. See implementation-log.md's 2026-08-01 entry.

-- DropForeignKey
ALTER TABLE "tenants" DROP CONSTRAINT "tenants_created_by_fkey";

-- DropForeignKey
ALTER TABLE "users" DROP CONSTRAINT "users_tenant_id_fkey";

-- AddForeignKey
ALTER TABLE "tenants" ADD CONSTRAINT "tenants_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED;

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE NO ACTION ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED;
