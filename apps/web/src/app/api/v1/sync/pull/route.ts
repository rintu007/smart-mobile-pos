import { NextRequest, NextResponse } from "next/server";
import { requireSession } from "@/core/auth/session";
import { ApiError } from "@/core/errors/api-error";
import { pullProducts } from "@/modules/sync/service";
import { syncPullQuerySchema } from "@/modules/sync/schema";

// docs/modules/sync-engine/specification.md#4-api-contract. Route Handlers are thin: parse,
// validate, call exactly one service method, shape the response —
// docs/08-folder-structure/backend-structure.md §2.

export async function GET(request: NextRequest) {
  try {
    const { tenantId } = await requireSession(request);

    const { searchParams } = new URL(request.url);
    const parsed = syncPullQuerySchema.safeParse({
      entity_type: searchParams.get("entity_type") ?? undefined,
      cursor: searchParams.get("cursor") ?? undefined,
      limit: searchParams.get("limit") ?? undefined,
    });
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Query parameters failed validation.", {
        issues: parsed.error.issues,
      });
    }

    // entity_type's own Zod enum currently only allows 'products' — this switch is here so a
    // future entity type added to the schema doesn't fall through silently to a wrong handler.
    if (parsed.data.entity_type === "products") {
      const result = await pullProducts(tenantId, parsed.data.cursor, parsed.data.limit);
      return NextResponse.json(result);
    }

    throw new ApiError(422, "VALIDATION_FAILED", `Unsupported entity_type: ${parsed.data.entity_type}`);
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}
