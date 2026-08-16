import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError } from "@/core/errors/api-error";
import { openTradingDay } from "@/modules/trading-day/service";
import { openTradingDayRequestSchema } from "@/modules/trading-day/schema";

// docs/modules/trading-day/specification.md#4-api-contract. A static sibling of `[id]/`, not
// nested under it — Sprint 23's own routing lesson applied from the start (Sprint 24/25 already
// repeated this precedent), avoiding any static-vs-dynamic collision.

export async function POST(request: NextRequest) {
  try {
    const { tenantId, storeId, userId } = await requirePermission(request, [
      "cashier",
      "manager",
      "owner",
    ]);

    const body = await request.json();
    const parsed = openTradingDayRequestSchema.safeParse(body);
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Request body failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await openTradingDay(tenantId, storeId, userId, parsed.data);
    return NextResponse.json(result, { status: 201 });
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}
