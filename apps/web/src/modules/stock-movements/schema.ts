import { z } from "zod";

// docs/modules/inventory/specification.md §5 — request body for POST /api/v1/stock-movements.
// `movement_type` deliberately excludes 'opening' — every product already gets one automatically
// at creation (products/repository.ts), and no live workflow needs a second, client-initiated
// write (spec §1). 'sale'/'return' pass schema validation but are rejected in the service layer
// with the specific DIRECT_SALE_MOVEMENT_FORBIDDEN error, not a generic VALIDATION_FAILED.
export const ADJUSTMENT_REASON_CODES = [
  "damage",
  "expiry",
  "loss_theft",
  "count_correction",
  "other",
] as const;

export const createStockMovementRequestSchema = z.object({
  id: z.string().uuid(),
  product_id: z.string().uuid(),
  quantity_delta: z
    .number()
    .int()
    .refine((value) => value !== 0, "quantity_delta must not be zero."),
  movement_type: z.enum(["adjustment", "sale", "return"]),
  reason_code: z.enum(ADJUSTMENT_REASON_CODES).optional(),
});

export type CreateStockMovementRequest = z.infer<typeof createStockMovementRequestSchema>;

// docs/modules/inventory/specification.md §5 — query params for GET /api/v1/stock-movements.
// `movement_type` accepts all four schema values here (unlike the create endpoint) — 'opening' is
// a real value already present in the table, and the movement-history view needs to show it.
export const listStockMovementsQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().positive().max(200).default(50),
  product_id: z.string().uuid().optional(),
  movement_type: z.enum(["opening", "sale", "return", "adjustment"]).optional(),
  date_from: z.string().datetime().optional(),
  date_to: z.string().datetime().optional(),
});

export type ListStockMovementsQuery = z.infer<typeof listStockMovementsQuerySchema>;
