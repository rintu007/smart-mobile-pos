-- CreateIndex
CREATE INDEX "sales_tenant_id_customer_id_completed_at_idx" ON "sales"("tenant_id", "customer_id", "completed_at");

-- CreateIndex
CREATE INDEX "products_tenant_id_category_id_idx" ON "products"("tenant_id", "category_id");
