import { z } from "zod";

// docs/11-api/endpoints/identity.md#audit-log — query params for GET /api/v1/audit-log.
export const listAuditLogQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().positive().max(200).default(50),
  entity_type: z.string().trim().min(1).max(100).optional(),
  entity_id: z.string().uuid().optional(),
  date_from: z.string().datetime().optional(),
  date_to: z.string().datetime().optional(),
});

export type ListAuditLogQuery = z.infer<typeof listAuditLogQuerySchema>;
