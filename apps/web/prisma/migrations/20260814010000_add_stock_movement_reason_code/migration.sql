-- AlterTable
ALTER TABLE "stock_movements" ADD COLUMN     "reason_code" TEXT;

-- CreateIndex
CREATE INDEX "stock_movements_tenant_id_store_id_created_at_idx" ON "stock_movements"("tenant_id", "store_id", "created_at");

