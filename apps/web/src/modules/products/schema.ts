import { z } from "zod";

// docs/modules/products/specification.md §5 — request body for POST /api/v1/products.
export const createProductRequestSchema = z.object({
  id: z.string().uuid(),
  name: z.string().trim().min(1).max(200),
  price_minor_units: z.number().int().nonnegative(),
  // docs/modules/products/specification.md §1's dated correction (Sprint 19, backlog item 3):
  // catalogue.md/FR-032/FR-035's full V1 shape requires these, but they stay optional here —
  // making them mandatory today would break both the 4 real products already in production
  // (created before this sprint) and mobile's `/catalogue/add`, which can't supply them until
  // backlog item 4's mobile catalogue UI ships.
  category_id: z.string().uuid().optional(),
  unit_id: z.string().uuid().optional(),
  sku: z.string().trim().min(1).max(100).optional(),
  barcode: z.string().trim().min(1).max(100).optional(),
  hsn_sac_code: z.string().trim().min(1).max(20).optional(),
  // docs/modules/inventory/specification.md §5 — optional, defaults to 0. Not part of
  // catalogue.md's documented request shape; a named, minimal addition (backlog.md item 7) so
  // every product creation produces exactly one opening stock-ledger entry, per DR-006.
  initial_quantity: z.number().int().nonnegative().optional(),
});

export type CreateProductRequest = z.infer<typeof createProductRequestSchema>;
