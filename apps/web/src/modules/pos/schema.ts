import { z } from "zod";

// docs/modules/pos/specification.md §5 — request body for POST /api/v1/sales. M0-minimal:
// cash-only, no discount/tax/trading-day/device (see sales.md's own dated correction note).
export const createSaleRequestSchema = z.object({
  id: z.string().uuid(),
  store_id: z.string().uuid(),
  provisional_invoice_number: z.string().trim().min(1).max(100),
  line_items: z
    .array(
      z.object({
        product_id: z.string().uuid(),
        quantity: z.number().int().positive(),
        client_unit_price_minor_units: z.number().int().nonnegative(),
      }),
    )
    .min(1),
  payments: z
    .array(
      z.object({
        method: z.literal("cash"),
        amount_minor_units: z.number().int().nonnegative(),
      }),
    )
    .length(1),
});

export type CreateSaleRequest = z.infer<typeof createSaleRequestSchema>;
