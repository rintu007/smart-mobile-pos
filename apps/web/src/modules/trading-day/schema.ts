import { z } from "zod";

// docs/modules/trading-day/specification.md §5 — request body for POST /api/v1/trading-days/open.
export const openTradingDayRequestSchema = z.object({
  id: z.string().uuid(),
  starting_float_minor_units: z.number().int().nonnegative(),
});

export type OpenTradingDayRequest = z.infer<typeof openTradingDayRequestSchema>;

// docs/modules/trading-day/specification.md §5 — request body for
// POST /api/v1/trading-days/{id}/close.
export const closeTradingDayRequestSchema = z.object({
  counted_cash_minor_units: z.number().int().nonnegative(),
});

export type CloseTradingDayRequest = z.infer<typeof closeTradingDayRequestSchema>;
