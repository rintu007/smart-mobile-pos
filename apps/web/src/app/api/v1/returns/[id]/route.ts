import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { getReturnDetail } from "@/modules/returns/service";

// docs/modules/returns/specification.md#4-api-contract.

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const { tenantId } = await requirePermission(request, ["cashier", "manager", "owner"]);
    const { id } = await params;

    const result = await getReturnDetail(tenantId, id);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
