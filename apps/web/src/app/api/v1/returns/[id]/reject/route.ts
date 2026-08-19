import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { rejectReturn } from "@/modules/returns/service";
import { rejectReturnRequestSchema } from "@/modules/returns/schema";

// docs/modules/returns/specification.md#4-api-contract. A static child of `[id]/`, sibling of
// `approve/route.ts`.

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const { authUserId, tenantId } = await requirePermission(request, ["manager", "owner"]);
    const { id } = await params;

    const body = await request.json();
    const parsed = rejectReturnRequestSchema.safeParse(body);
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Request body failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await rejectReturn(authUserId, tenantId, id, parsed.data.reason);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
