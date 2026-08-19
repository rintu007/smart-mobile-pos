import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { listConflicts } from "@/modules/customers/service";
import { listConflictsQuerySchema } from "@/modules/customers/schema";

// docs/modules/customers/specification.md#4-api-contract. A static sibling of `[id]/route.ts`, not
// nested under it — the same static-vs-dynamic routing lesson `POST /users/invite` learned the hard
// way (Sprint 23), applied proactively here so a literal `conflicts` segment never falls through to
// `[id]`'s own dynamic match.

export async function GET(request: NextRequest) {
  try {
    const { tenantId } = await requirePermission(request, ["manager", "owner"]);

    const { searchParams } = new URL(request.url);
    const parsed = listConflictsQuerySchema.safeParse({
      cursor: searchParams.get("cursor") ?? undefined,
      limit: searchParams.get("limit") ?? undefined,
    });
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Query parameters failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await listConflicts(tenantId, parsed.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
