import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { listApprovals } from "@/modules/returns/service";
import { listReturnsQuerySchema } from "@/modules/returns/schema";

// docs/modules/returns/specification.md#4-api-contract. A static sibling of `[id]/`, not nested
// under it — Trading Day/Customers' own proactive static-route-first precedent applied from the
// start, avoiding any static-vs-dynamic collision.

export async function GET(request: NextRequest) {
  try {
    const { tenantId } = await requirePermission(request, ["manager", "owner"]);

    const { searchParams } = new URL(request.url);
    const parsed = listReturnsQuerySchema.safeParse({
      cursor: searchParams.get("cursor") ?? undefined,
      limit: searchParams.get("limit") ?? undefined,
    });
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Query parameters failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await listApprovals(tenantId, parsed.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
