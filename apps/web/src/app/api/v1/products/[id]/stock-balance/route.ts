import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { getStockBalance } from "@/modules/stock-movements/service";

// docs/modules/inventory/specification.md#4-api-contract. Route Handlers are thin: parse,
// validate, call exactly one service method, shape the response —
// docs/08-folder-structure/backend-structure.md §2.

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const { tenantId } = await requirePermission(request, ["cashier", "manager", "owner"]);
    const { id } = await params;

    const result = await getStockBalance(tenantId, id);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
