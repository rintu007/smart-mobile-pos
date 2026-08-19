import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { inviteUser } from "@/modules/roles/service";
import { inviteUserRequestSchema } from "@/modules/roles/schema";

// docs/modules/roles-permissions/specification.md#4-api-contract. Route Handlers are thin: parse,
// validate, call exactly one service method, shape the response —
// docs/08-folder-structure/backend-structure.md §2.

export async function POST(request: NextRequest) {
  try {
    const { authUserId, tenantId } = await requirePermission(request, ["owner"]);

    const body = await request.json();
    const parsed = inviteUserRequestSchema.safeParse(body);
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Request body failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await inviteUser(authUserId, tenantId, parsed.data);
    return NextResponse.json(result, { status: 201 });
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
