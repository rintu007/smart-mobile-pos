import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import type { AuditLogCursor } from "./repository";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

function formatAuditLogEntry(entry: {
  id: string;
  storeId: string | null;
  actorUserId: string;
  action: string;
  entityType: string;
  entityId: string;
  beforeState: unknown;
  afterState: unknown;
  createdAt: Date;
}) {
  return {
    id: entry.id,
    store_id: entry.storeId,
    actor_user_id: entry.actorUserId,
    action: entry.action,
    entity_type: entry.entityType,
    entity_id: entry.entityId,
    before_state: entry.beforeState,
    after_state: entry.afterState,
    created_at: entry.createdAt.toISOString(),
  };
}

/**
 * docs/11-api/endpoints/identity.md#audit-log — GET /api/v1/audit-log (Sprint 23, closing the gap
 * named in docs/modules/audit-log/specification.md §1: this endpoint was deferred pending Roles &
 * Permissions, which now exists).
 */
export async function listAuditLog(
  tenantId: string,
  query: {
    cursor?: string;
    limit: number;
    entity_type?: string;
    entity_id?: string;
    date_from?: string;
    date_to?: string;
  },
) {
  const decodedCursor = query.cursor ? decodeCursor(query.cursor) : null;
  const fetched = await repository.listAuditLog(
    tenantId,
    {
      entityType: query.entity_type,
      entityId: query.entity_id,
      dateFrom: query.date_from ? new Date(query.date_from) : undefined,
      dateTo: query.date_to ? new Date(query.date_to) : undefined,
    },
    decodedCursor,
    query.limit,
  );
  // Peek-and-trim, same reasoning every other list endpoint in this codebase already established.
  const hasMore = fetched.length > query.limit;
  const rows = hasMore ? fetched.slice(0, query.limit) : fetched;
  const lastRow = rows[rows.length - 1];
  const nextCursor = hasMore && lastRow ? encodeCursor(lastRow) : null;

  return {
    data: rows.map((entry) => formatAuditLogEntry(entry)),
    next_cursor: nextCursor,
  };
}

function encodeCursor(row: AuditLogCursor): string {
  return Buffer.from(`${row.createdAt.toISOString()}|${row.id}`).toString("base64url");
}

function decodeCursor(cursor: string): AuditLogCursor {
  let createdAtIso: string | undefined;
  let id: string | undefined;
  try {
    [createdAtIso, id] = Buffer.from(cursor, "base64url").toString("utf8").split("|");
  } catch {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }

  const createdAt = createdAtIso ? new Date(createdAtIso) : undefined;
  if (!createdAt || Number.isNaN(createdAt.getTime()) || !id) {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }

  return { createdAt, id };
}
