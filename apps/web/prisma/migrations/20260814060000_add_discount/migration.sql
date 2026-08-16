-- AlterTable
ALTER TABLE "sale_line_items" ADD COLUMN     "line_discount_minor_units" BIGINT NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "sales" ADD COLUMN     "discount_total_minor_units" BIGINT NOT NULL DEFAULT 0;
