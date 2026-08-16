import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError } from "@/core/errors/api-error";
import { approveReturn } from "@/modules/returns/service";

// docs/modules/returns/specification.md#4-api-contract. A static child of `[id]/`, sibling of
// `reject/route.ts` — no dynamic segment at this nesting level, so no collision risk. No request
// body: the target id travels via the URL, unlike the sync-push payload shape (specification.md §5).

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const { authUserId, tenantId } = await requirePermission(request, ["manager", "owner"]);
    const { id } = await params;

    const result = await approveReturn(authUserId, tenantId, id);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}
