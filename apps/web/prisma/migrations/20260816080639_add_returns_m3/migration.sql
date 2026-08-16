-- CreateTable
CREATE TABLE "returns" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "store_id" UUID NOT NULL,
    "original_sale_id" UUID NOT NULL,
    "status" TEXT NOT NULL,
    "refund_total_minor_units" BIGINT NOT NULL,
    "approved_by" UUID,
    "completed_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" UUID NOT NULL,

    CONSTRAINT "returns_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "return_line_items" (
    "id" UUID NOT NULL,
    "return_id" UUID NOT NULL,
    "original_sale_line_item_id" UUID NOT NULL,
    "quantity" INTEGER NOT NULL,
    "refund_amount_minor_units" BIGINT NOT NULL,

    CONSTRAINT "return_line_items_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "returns_original_sale_id_idx" ON "returns"("original_sale_id");

-- CreateIndex
CREATE INDEX "returns_tenant_id_store_id_status_idx" ON "returns"("tenant_id", "store_id", "status");

-- CreateIndex
CREATE INDEX "returns_tenant_id_created_at_idx" ON "returns"("tenant_id", "created_at");

-- CreateIndex
CREATE INDEX "return_line_items_original_sale_line_item_id_idx" ON "return_line_items"("original_sale_line_item_id");

-- AddForeignKey
ALTER TABLE "returns" ADD CONSTRAINT "returns_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "returns" ADD CONSTRAINT "returns_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "stores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "returns" ADD CONSTRAINT "returns_original_sale_id_fkey" FOREIGN KEY ("original_sale_id") REFERENCES "sales"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "returns" ADD CONSTRAINT "returns_approved_by_fkey" FOREIGN KEY ("approved_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "returns" ADD CONSTRAINT "returns_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "return_line_items" ADD CONSTRAINT "return_line_items_return_id_fkey" FOREIGN KEY ("return_id") REFERENCES "returns"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "return_line_items" ADD CONSTRAINT "return_line_items_original_sale_line_item_id_fkey" FOREIGN KEY ("original_sale_line_item_id") REFERENCES "sale_line_items"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
