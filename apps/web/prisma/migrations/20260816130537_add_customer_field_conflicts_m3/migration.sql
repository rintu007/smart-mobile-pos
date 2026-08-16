-- AlterTable
ALTER TABLE "customers" ADD COLUMN     "updated_by" UUID;

-- CreateTable
CREATE TABLE "customer_field_conflicts" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "customer_id" UUID NOT NULL,
    "field" TEXT NOT NULL,
    "current_value" TEXT,
    "current_set_by" UUID NOT NULL,
    "attempted_value" TEXT,
    "attempted_set_by" UUID NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMPTZ,
    "resolved_value" TEXT,
    "resolved_by" UUID,

    CONSTRAINT "customer_field_conflicts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "customer_field_conflicts_tenant_id_resolved_at_idx" ON "customer_field_conflicts"("tenant_id", "resolved_at");

-- AddForeignKey
ALTER TABLE "customers" ADD CONSTRAINT "customers_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_field_conflicts" ADD CONSTRAINT "customer_field_conflicts_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_field_conflicts" ADD CONSTRAINT "customer_field_conflicts_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_field_conflicts" ADD CONSTRAINT "customer_field_conflicts_current_set_by_fkey" FOREIGN KEY ("current_set_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_field_conflicts" ADD CONSTRAINT "customer_field_conflicts_attempted_set_by_fkey" FOREIGN KEY ("attempted_set_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_field_conflicts" ADD CONSTRAINT "customer_field_conflicts_resolved_by_fkey" FOREIGN KEY ("resolved_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
