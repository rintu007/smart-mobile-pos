import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { closeTradingDay } from "@/modules/trading-day/service";
import { closeTradingDayRequestSchema } from "@/modules/trading-day/schema";

// docs/modules/trading-day/specification.md#4-api-contract. A static child of `[id]/`, sibling of
// `reopen/route.ts` — no dynamic segment at this nesting level, so no collision risk.

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const { tenantId, storeId, userId } = await requirePermission(request, [
      "cashier",
      "manager",
      "owner",
    ]);
    const { id } = await params;

    const body = await request.json();
    const parsed = closeTradingDayRequestSchema.safeParse(body);
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Request body failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await closeTradingDay(tenantId, storeId, userId, id, parsed.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
