import { z } from "zod";

// docs/modules/sync-engine/specification.md §5 — request body for POST /api/v1/sync/push.
// `payload` is intentionally untyped here: sync-api.md §1 says push does not define a second,
// parallel request schema, so each operation's payload is validated per-type against the exact
// same schema its direct endpoint already uses (service.ts does that, not this file).
export const syncPushOperationSchema = z.object({
  // `customer.create` added Sprint 32 (backlog.md M3 item 2) —
  // docs/modules/customers/specification.md §1a.
  type: z.enum(["product.create", "sale.create", "customer.create"]),
  client_operation_id: z.string().uuid(),
  payload: z.record(z.string(), z.unknown()),
});

export const syncPushRequestSchema = z.object({
  operations: z.array(syncPushOperationSchema).min(1).max(200),
});

export type SyncPushOperation = z.infer<typeof syncPushOperationSchema>;
export type SyncPushRequest = z.infer<typeof syncPushRequestSchema>;

// docs/modules/sync-engine/specification.md §5 — query params for GET /api/v1/sync/pull.
// `entity_type` is `'products'` only this sprint — sync-api.md §6 documents eight, of which this
// is the first ever implemented.
export const syncPullQuerySchema = z.object({
  entity_type: z.enum(["products"]),
  cursor: z.string().optional(),
  limit: z.coerce.number().int().positive().max(200).default(50),
});

export type SyncPullQuery = z.infer<typeof syncPullQuerySchema>;
