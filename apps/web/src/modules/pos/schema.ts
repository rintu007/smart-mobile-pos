import { z } from "zod";

// docs/modules/pos/specification.md §5 — request body for POST /api/v1/sales. M0-minimal:
// cash-only, no discount/tax/device (see sales.md's own dated correction note).
// `trading_day_id` added Sprint 26 (backlog.md M2 item 2) — optional, linked when supplied, but
// not yet required: docs/modules/trading-day/specification.md §1's named, dated deferral of the
// TRADING_DAY_NOT_OPEN gate until the mobile till screen opens a day first.
export const createSaleRequestSchema = z.object({
  id: z.string().uuid(),
  store_id: z.string().uuid(),
  trading_day_id: z.string().uuid().optional(),
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
