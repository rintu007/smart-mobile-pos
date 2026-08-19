import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { deactivateUser } from "@/modules/roles/service";

// docs/modules/roles-permissions/specification.md#4-api-contract. Route Handlers are thin: parse,
// validate, call exactly one service method, shape the response —
// docs/08-folder-structure/backend-structure.md §2.

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const { authUserId, tenantId } = await requirePermission(request, ["owner"]);
    const { id } = await params;

    const result = await deactivateUser(authUserId, tenantId, id);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
