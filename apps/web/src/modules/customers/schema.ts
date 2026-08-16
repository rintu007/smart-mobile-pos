import { z } from "zod";

// docs/modules/customers/specification.md §5 — request body for POST /api/v1/customers.
// "At least one of name/phone" is deliberately NOT a Zod .refine() here, even though it's a
// cross-field rule — found live (Sprint 31's own verification script): a .refine() failure is
// indistinguishable from any other shape violation, so the route always reports the generic
// VALIDATION_FAILED, never the specific CUSTOMER_IDENTIFIER_REQUIRED customers.md names for this
// exact condition. service.ts's assertHasIdentifier() enforces this instead, matching this
// codebase's own "business rules live in the service layer, not the Route Handler" convention
// (docs/08-folder-structure/backend-structure.md §2) for any rule that needs a named error code —
// distinct from pos/schema.ts's discount-fields .refine(), which has no named code to preserve.
export const createCustomerRequestSchema = z.object({
  id: z.string().uuid(),
  name: z.string().trim().min(1).max(200).optional(),
  phone: z.string().trim().min(1).max(20).optional(),
});

export type CreateCustomerRequest = z.infer<typeof createCustomerRequestSchema>;

// docs/modules/customers/specification.md §5 — PATCH /api/v1/customers/{id}. Both fields
// independently optional; the "would leave both null" case is checked in service.ts against the
// existing row, not here, since this schema alone can't see what's already stored.
export const updateCustomerRequestSchema = z.object({
  name: z.string().trim().min(1).max(200).nullable().optional(),
  phone: z.string().trim().min(1).max(20).nullable().optional(),
});

export type UpdateCustomerRequest = z.infer<typeof updateCustomerRequestSchema>;

// docs/modules/customers/specification.md §4 — GET /api/v1/customers query params.
export const listCustomersQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().positive().max(200).default(50),
  phone: z.string().trim().min(1).max(20).optional(),
});

export type ListCustomersQuery = z.infer<typeof listCustomersQuerySchema>;

// docs/modules/customers/specification.md §4 — GET /api/v1/customers/{id}/purchase-history.
export const purchaseHistoryQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().positive().max(200).default(50),
});

export type PurchaseHistoryQuery = z.infer<typeof purchaseHistoryQuerySchema>;
