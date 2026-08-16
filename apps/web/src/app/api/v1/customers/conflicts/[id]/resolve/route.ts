import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError } from "@/core/errors/api-error";
import { resolveConflict } from "@/modules/customers/service";
import { resolveConflictRequestSchema } from "@/modules/customers/schema";

// docs/modules/customers/specification.md#4-api-contract.

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const { authUserId, tenantId } = await requirePermission(request, ["manager", "owner"]);
    const { id } = await params;

    const body = await request.json();
    const parsed = resolveConflictRequestSchema.safeParse(body);
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Request body failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await resolveConflict(authUserId, tenantId, id, parsed.data.resolved_value);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}
