-- CreateTable
CREATE TABLE "shop_settings" (
    "tenant_id" UUID NOT NULL,
    "tax_mode" TEXT NOT NULL,
    "tax_rate_basis_points" INTEGER NOT NULL DEFAULT 0,
    "pricing_mode" TEXT NOT NULL,
    "rounding_rule" TEXT NOT NULL,
    "currency_code" TEXT NOT NULL DEFAULT 'INR',
    "discount_auto_approval_threshold_minor_units" BIGINT NOT NULL,
    "return_auto_approval_threshold_minor_units" BIGINT NOT NULL,
    "printer_config" JSONB,
    "receipt_template_config" JSONB,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" UUID NOT NULL,

    CONSTRAINT "shop_settings_pkey" PRIMARY KEY ("tenant_id")
);

-- AddForeignKey
ALTER TABLE "shop_settings" ADD CONSTRAINT "shop_settings_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;

