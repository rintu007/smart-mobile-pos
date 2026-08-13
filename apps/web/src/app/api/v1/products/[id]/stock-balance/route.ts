import { NextRequest, NextResponse } from "next/server";
import { requireSession } from "@/core/auth/session";
import { ApiError } from "@/core/errors/api-error";
import { getStockBalance } from "@/modules/stock-movements/service";

// docs/modules/inventory/specification.md#4-api-contract. Route Handlers are thin: parse,
// validate, call exactly one service method, shape the response —
// docs/08-folder-structure/backend-structure.md §2.

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const { tenantId } = await requireSession(request);
    const { id } = await params;

    const result = await getStockBalance(tenantId, id);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}
