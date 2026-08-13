import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError } from "@/core/errors/api-error";
import { listUsers } from "@/modules/roles/service";
import { listUsersQuerySchema } from "@/modules/roles/schema";

// docs/modules/roles-permissions/specification.md#4-api-contract. Route Handlers are thin: parse,
// validate, call exactly one service method, shape the response —
// docs/08-folder-structure/backend-structure.md §2. `POST /users/invite` lives in its own
// `users/invite/route.ts` (a static sibling path, not this collection route) — Next.js's own
// dynamic-segment matching would otherwise resolve `/users/invite` to `users/[id]/route.ts` with
// `id: "invite"` instead, a real routing bug found live (a 405, not a 404, since that file exists
// but only exports DELETE) rather than by inspection.

export async function GET(request: NextRequest) {
  try {
    const { tenantId } = await requirePermission(request, ["manager", "owner"]);

    const { searchParams } = new URL(request.url);
    const parsed = listUsersQuerySchema.safeParse({
      cursor: searchParams.get("cursor") ?? undefined,
      limit: searchParams.get("limit") ?? undefined,
    });
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Query parameters failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await listUsers(tenantId, parsed.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}
