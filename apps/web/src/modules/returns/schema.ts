import { z } from "zod";

// docs/modules/returns/specification.md §5 — request body for POST /api/v1/returns. Refund amounts
// are never accepted from the client (§4/DR-014, api-principles.md §7) — server-computed only.
export const createReturnRequestSchema = z.object({
  id: z.string().uuid(),
  original_sale_id: z.string().uuid(),
  line_items: z
    .array(
      z.object({
        original_sale_line_item_id: z.string().uuid(),
        quantity: z.number().int().positive(),
      }),
    )
    .min(1),
});

export type CreateReturnRequest = z.infer<typeof createReturnRequestSchema>;

// docs/modules/returns/specification.md §5 — request body for POST /api/v1/returns/{id}/reject.
// The target id travels via the URL for this direct endpoint, not this schema.
export const rejectReturnRequestSchema = z.object({
  reason: z.string().trim().min(1).max(500),
});

export type RejectReturnRequest = z.infer<typeof rejectReturnRequestSchema>;

// docs/modules/returns/specification.md §5 — GET /api/v1/returns and GET /api/v1/returns/approvals
// query params. `initiated`/`approved` are excluded from the filterable set: no row is ever produced
// in those states this sprint (specification.md §1, correction 3).
export const listReturnsQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().positive().max(200).default(50),
  status: z.enum(["pending_approval", "completed", "rejected"]).optional(),
});

export type ListReturnsQuery = z.infer<typeof listReturnsQuerySchema>;

// docs/modules/returns/specification.md §5 — a sync-push operation has no URL, so
// `return.approve`/`return.reject`'s payloads carry the target `id` themselves, unlike the direct
// endpoints' own bodies (a structural difference, not an inconsistency — see specification.md §5).
export const syncApproveReturnPayloadSchema = z.object({
  id: z.string().uuid(),
});

export type SyncApproveReturnPayload = z.infer<typeof syncApproveReturnPayloadSchema>;

export const syncRejectReturnPayloadSchema = z.object({
  id: z.string().uuid(),
  reason: z.string().trim().min(1).max(500),
});

export type SyncRejectReturnPayload = z.infer<typeof syncRejectReturnPayloadSchema>;
