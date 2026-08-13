import * as identityService from "@/modules/identity/service";
import * as repository from "./repository";
import type { CategoryCursor } from "./repository";
import { ApiError } from "@/core/errors/api-error";
import type { CreateCategoryRequest } from "./schema";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

/**
 * docs/modules/categories/specification.md#4-api-contract.
 *
 * No permission check beyond a valid tenant-scoped session — Roles & Permissions doesn't exist
 * yet (§1 of the spec), the same named scope boundary every M0 module already used.
 */
export async function createCategory(
  authUserId: string,
  tenantId: string,
  input: CreateCategoryRequest,
) {
  const createdBy = await identityService.resolveUserId(authUserId);

  const category = await repository.createCategory({ ...input, tenantId, createdBy });

  return {
    id: category.id,
    name: category.name,
    created_at: category.createdAt.toISOString(),
  };
}

export async function listCategories(tenantId: string, cursor: string | undefined, limit: number) {
  const decodedCursor = cursor ? decodeCursor(cursor) : null;
  const fetched = await repository.listCategories(tenantId, decodedCursor, limit);
  // Peek-and-trim, same reasoning sync/service.ts's pull already established.
  const hasMore = fetched.length > limit;
  const rows = hasMore ? fetched.slice(0, limit) : fetched;
  const lastRow = rows[rows.length - 1];
  const nextCursor = hasMore && lastRow ? encodeCursor(lastRow) : null;

  return {
    data: rows.map((category) => ({
      id: category.id,
      name: category.name,
      created_at: category.createdAt.toISOString(),
    })),
    next_cursor: nextCursor,
  };
}

function encodeCursor(row: CategoryCursor): string {
  return Buffer.from(`${row.createdAt.toISOString()}|${row.id}`).toString("base64url");
}

function decodeCursor(cursor: string): CategoryCursor {
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
