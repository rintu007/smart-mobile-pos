import { z } from "zod";

// docs/modules/sales-invoices/specification.md §5 — query params for GET /api/v1/sales.
export const listSalesQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().positive().max(200).default(50),
  date_from: z.string().datetime().optional(),
  date_to: z.string().datetime().optional(),
});

export type ListSalesQuery = z.infer<typeof listSalesQuerySchema>;

// docs/modules/sales-invoices/specification.md §5 — query params for GET /api/v1/sales/lookup.
// Exactly one of the two identifiers is required — neither or both is a validation failure, not a
// silently-ignored extra field.
export const lookupSaleQuerySchema = z
  .object({
    provisional_invoice_number: z.string().trim().min(1).optional(),
    canonical_invoice_number: z.coerce.number().int().positive().optional(),
  })
  .refine(
    (data) =>
      (data.provisional_invoice_number !== undefined ? 1 : 0) +
        (data.canonical_invoice_number !== undefined ? 1 : 0) ===
      1,
    { message: "Exactly one of provisional_invoice_number or canonical_invoice_number is required." },
  );

export type LookupSaleQuery = z.infer<typeof lookupSaleQuerySchema>;
