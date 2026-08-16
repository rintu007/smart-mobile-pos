-- AlterTable
ALTER TABLE "sale_line_items" ADD COLUMN     "line_tax_minor_units" BIGINT NOT NULL DEFAULT 0,
ADD COLUMN     "tax_rate_basis_points" INTEGER NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "sales" ADD COLUMN     "tax_registration_type_at_sale" TEXT,
ADD COLUMN     "tax_total_minor_units" BIGINT NOT NULL DEFAULT 0;
