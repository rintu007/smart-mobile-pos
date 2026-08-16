import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError } from "@/core/errors/api-error";
import { getCurrentTradingDay } from "@/modules/trading-day/service";

// docs/modules/trading-day/specification.md#4-api-contract. A static sibling of `[id]/`, matching
// `open/route.ts`'s own reasoning.

export async function GET(request: NextRequest) {
  try {
    const { tenantId, storeId } = await requirePermission(request, [
      "cashier",
      "manager",
      "owner",
    ]);

    const result = await getCurrentTradingDay(tenantId, storeId);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}
