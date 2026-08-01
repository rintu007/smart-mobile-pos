import { z } from "zod";

// docs/modules/products/specification.md §5 — request body for POST /api/v1/products. M0-minimal:
// name/price only, not catalogue.md's full shape (see that document's own dated correction note).
export const createProductRequestSchema = z.object({
  id: z.string().uuid(),
  name: z.string().trim().min(1).max(200),
  price_minor_units: z.number().int().nonnegative(),
});

export type CreateProductRequest = z.infer<typeof createProductRequestSchema>;
