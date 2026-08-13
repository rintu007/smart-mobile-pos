import * as identityService from "@/modules/identity/service";
import * as repository from "./repository";
import type { UnitCursor } from "./repository";
import { ApiError } from "@/core/errors/api-error";
import type { CreateUnitRequest } from "./schema";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

/**
 * docs/modules/units/specification.md#4-api-contract.
 *
 * No permission check beyond a valid tenant-scoped session — Roles & Permissions doesn't exist
 * yet (§1 of the spec), the same named scope boundary Categories (Sprint 17) already used.
 */
export async function createUnit(
  authUserId: string,
  tenantId: string,
  input: CreateUnitRequest,
) {
  const createdBy = await identityService.resolveUserId(authUserId);

  const unit = await repository.createUnit({ ...input, tenantId, createdBy });

  return {
    id: unit.id,
    name: unit.name,
    symbol: unit.symbol,
    allows_fractional: unit.allowsFractional,
    created_at: unit.createdAt.toISOString(),
  };
}

export async function listUnits(tenantId: string, cursor: string | undefined, limit: number) {
  const decodedCursor = cursor ? decodeCursor(cursor) : null;
  const fetched = await repository.listUnits(tenantId, decodedCursor, limit);
  // Peek-and-trim, same reasoning categories/service.ts's list already established.
  const hasMore = fetched.length > limit;
  const rows = hasMore ? fetched.slice(0, limit) : fetched;
  const lastRow = rows[rows.length - 1];
  const nextCursor = hasMore && lastRow ? encodeCursor(lastRow) : null;

  return {
    data: rows.map((unit) => ({
      id: unit.id,
      name: unit.name,
      symbol: unit.symbol,
      allows_fractional: unit.allowsFractional,
      created_at: unit.createdAt.toISOString(),
    })),
    next_cursor: nextCursor,
  };
}

function encodeCursor(row: UnitCursor): string {
  return Buffer.from(`${row.createdAt.toISOString()}|${row.id}`).toString("base64url");
}

function decodeCursor(cursor: string): UnitCursor {
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
