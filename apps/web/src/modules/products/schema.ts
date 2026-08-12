import { z } from "zod";

// docs/modules/products/specification.md §5 — request body for POST /api/v1/products. M0-minimal:
// name/price only, not catalogue.md's full shape (see that document's own dated correction note).
export const createProductRequestSchema = z.object({
  id: z.string().uuid(),
  name: z.string().trim().min(1).max(200),
  price_minor_units: z.number().int().nonnegative(),
  // docs/modules/inventory/specification.md §5 — optional, defaults to 0. Not part of
  // catalogue.md's documented request shape; a named, minimal addition (backlog.md item 7) so
  // every product creation produces exactly one opening stock-ledger entry, per DR-006.
  initial_quantity: z.number().int().nonnegative().optional(),
});

export type CreateProductRequest = z.infer<typeof createProductRequestSchema>;
