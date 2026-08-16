import { z } from "zod";

// docs/modules/pos/specification.md §5 — request body for POST /api/v1/sales. M0-minimal:
// cash-only, no tax/device (see sales.md's own dated correction note).
// `trading_day_id` added Sprint 26 (backlog.md M2 item 2) — optional, linked when supplied, but
// not yet required: docs/modules/trading-day/specification.md §1's named, dated deferral of the
// TRADING_DAY_NOT_OPEN gate until the mobile till screen opens a day first.
// `discount_percent_basis_points`/`discount_amount_minor_units`/`discount_approved_by` added
// Sprint 27 (backlog.md M2 item 3) — DR-011/DR-012.
const lineItemSchema = z
  .object({
    product_id: z.string().uuid(),
    quantity: z.number().int().positive(),
    client_unit_price_minor_units: z.number().int().nonnegative(),
    discount_percent_basis_points: z.number().int().min(0).max(10000).optional(),
    discount_amount_minor_units: z.number().int().nonnegative().optional(),
  })
  .refine(
    (item) =>
      item.discount_percent_basis_points === undefined ||
      item.discount_amount_minor_units === undefined,
    { message: "A line item cannot carry both a percent and a fixed discount." },
  );

export const createSaleRequestSchema = z.object({
  id: z.string().uuid(),
  store_id: z.string().uuid(),
  trading_day_id: z.string().uuid().optional(),
  provisional_invoice_number: z.string().trim().min(1).max(100),
  line_items: z.array(lineItemSchema).min(1),
  payments: z
    .array(
      z.object({
        method: z.literal("cash"),
        amount_minor_units: z.number().int().nonnegative(),
      }),
    )
    .length(1),
  discount_approved_by: z.string().uuid().optional(),
});

export type CreateSaleRequest = z.infer<typeof createSaleRequestSchema>;
