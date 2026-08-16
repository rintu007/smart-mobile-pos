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

// docs/modules/customers/specification.md §1c/§5 — PATCH /api/v1/customers/{id}, upgraded Sprint 35
// (backlog.md M3 item 5) to the merge-aware shape: a genuine, dated contract break from Sprint 31's
// original partial-update shape, judged safe since no mobile caller of PATCH ever existed before
// this sprint. All four fields are required, not just the changed one(s) — the field-level 3-way
// merge (service.ts's mergeCustomerFields) needs each field's own base value to detect overlap
// regardless of which field(s) this particular edit actually intends to change. `base_updated_at`
// is carried for fidelity to conflict-resolution.md §3's own vocabulary but is not separately
// branched on — see service.ts's own comment for why it's mathematically redundant with the
// per-field comparison.
export const updateCustomerRequestSchema = z.object({
  base_updated_at: z.string().datetime(),
  base_name: z.string().trim().min(1).max(200).nullable(),
  base_phone: z.string().trim().min(1).max(20).nullable(),
  name: z.string().trim().min(1).max(200).nullable(),
  phone: z.string().trim().min(1).max(20).nullable(),
});

export type UpdateCustomerRequest = z.infer<typeof updateCustomerRequestSchema>;

// docs/modules/customers/specification.md §5 — the customer.update sync-push payload: the same
// four fields as PATCH's body, plus `id` (the target customer, no URL to carry it in a push batch —
// the same structural difference return.approve/return.reject's own sync payloads already
// established, docs/modules/returns/specification.md §5).
export const syncUpdateCustomerPayloadSchema = updateCustomerRequestSchema.extend({
  id: z.string().uuid(),
});

export type SyncUpdateCustomerPayload = z.infer<typeof syncUpdateCustomerPayloadSchema>;

// docs/modules/customers/specification.md §5 — POST /api/v1/customers/conflicts/{id}/resolve.
export const resolveConflictRequestSchema = z.object({
  resolved_value: z.string().trim().min(1).max(200).nullable(),
});

export type ResolveConflictRequest = z.infer<typeof resolveConflictRequestSchema>;

// docs/modules/customers/specification.md §4 — GET /api/v1/customers/conflicts query params.
export const listConflictsQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().positive().max(200).default(50),
});

export type ListConflictsQuery = z.infer<typeof listConflictsQuerySchema>;

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
