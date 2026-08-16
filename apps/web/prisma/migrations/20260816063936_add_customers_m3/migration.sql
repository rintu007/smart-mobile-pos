-- AlterTable
ALTER TABLE "sales" ADD COLUMN     "customer_id" UUID;

-- CreateTable
CREATE TABLE "customers" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "name" TEXT,
    "phone" TEXT,
    "deactivated_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" UUID NOT NULL,

    CONSTRAINT "customers_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "customers_tenant_id_idx" ON "customers"("tenant_id");

-- CreateIndex (hand-edited addition — docs/modules/customers/specification.md §3, matching
-- schema-server.md's documented `(tenant_id, phone) WHERE deactivated_at IS NULL` exactly.
-- Prisma's schema DSL has no partial-unique-index syntax, the same DEFERRABLE-FK-style hand-edit
-- precedent Sprint 01 established, most recently for trading_days' own one-open-day-per-store
-- index. Postgres treats each NULL phone as distinct on its own, so no explicit `phone IS NOT
-- NULL` clause is needed for two customers who both omit a phone to coexist.)
CREATE UNIQUE INDEX "customers_tenant_id_phone_active_key" ON "customers"("tenant_id", "phone") WHERE "deactivated_at" IS NULL;

-- AddForeignKey
ALTER TABLE "sales" ADD CONSTRAINT "sales_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customers" ADD CONSTRAINT "customers_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customers" ADD CONSTRAINT "customers_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
