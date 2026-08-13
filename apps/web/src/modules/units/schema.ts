import { z } from "zod";

// docs/modules/units/specification.md §5 — request body for POST /api/v1/units.
export const createUnitRequestSchema = z.object({
  id: z.string().uuid(),
  name: z.string().trim().min(1).max(200),
  symbol: z.string().trim().min(1).max(20),
  allows_fractional: z.boolean().default(false),
});

export type CreateUnitRequest = z.infer<typeof createUnitRequestSchema>;

// docs/modules/units/specification.md §4 — query params for GET /api/v1/units.
export const listUnitsQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().positive().max(200).default(50),
});

export type ListUnitsQuery = z.infer<typeof listUnitsQuerySchema>;
