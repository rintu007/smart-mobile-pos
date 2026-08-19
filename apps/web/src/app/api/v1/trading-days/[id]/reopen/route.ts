import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { reopenTradingDay } from "@/modules/trading-day/service";

// docs/modules/trading-day/specification.md#4-api-contract. DR-020: Manager/Owner only. A static
// child of `[id]/`, sibling of `close/route.ts`.

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const { tenantId, storeId, userId } = await requirePermission(request, ["manager", "owner"]);
    const { id } = await params;

    const result = await reopenTradingDay(tenantId, storeId, userId, id);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
