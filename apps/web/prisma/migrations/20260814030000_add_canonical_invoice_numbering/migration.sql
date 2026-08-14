-- DropIndex
DROP INDEX "sales_tenant_id_idx";

-- AlterTable
ALTER TABLE "sales" ADD COLUMN     "canonical_invoice_number" BIGINT,
ADD COLUMN     "financial_year" TEXT;

-- CreateTable
CREATE TABLE "invoice_sequences" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "financial_year" TEXT NOT NULL,
    "next_value" BIGINT NOT NULL,

    CONSTRAINT "invoice_sequences_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "invoice_sequences_tenant_id_financial_year_key" ON "invoice_sequences"("tenant_id", "financial_year");

-- CreateIndex
CREATE INDEX "sales_tenant_id_store_id_completed_at_idx" ON "sales"("tenant_id", "store_id", "completed_at");

-- CreateIndex
CREATE UNIQUE INDEX "sales_tenant_id_provisional_invoice_number_key" ON "sales"("tenant_id", "provisional_invoice_number");

-- CreateIndex
CREATE UNIQUE INDEX "sales_tenant_id_financial_year_canonical_invoice_number_key" ON "sales"("tenant_id", "financial_year", "canonical_invoice_number");

-- AddForeignKey
ALTER TABLE "invoice_sequences" ADD CONSTRAINT "invoice_sequences_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

