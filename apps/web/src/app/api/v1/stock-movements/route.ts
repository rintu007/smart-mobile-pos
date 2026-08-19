import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { createStockMovement, listStockMovements } from "@/modules/stock-movements/service";
import {
  createStockMovementRequestSchema,
  listStockMovementsQuerySchema,
} from "@/modules/stock-movements/schema";

// docs/modules/inventory/specification.md#4-api-contract. Route Handlers are thin: parse,
// validate, call exactly one service method, shape the response —
// docs/08-folder-structure/backend-structure.md §2.

export async function POST(request: NextRequest) {
  try {
    const { authUserId, tenantId } = await requirePermission(request, ["manager", "owner"]);

    const body = await request.json();
    const parsed = createStockMovementRequestSchema.safeParse(body);
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Request body failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await createStockMovement(authUserId, tenantId, parsed.data);
    return NextResponse.json(result, { status: 201 });
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}

export async function GET(request: NextRequest) {
  try {
    const { tenantId } = await requirePermission(request, ["manager", "owner"]);

    const { searchParams } = new URL(request.url);
    const parsed = listStockMovementsQuerySchema.safeParse({
      cursor: searchParams.get("cursor") ?? undefined,
      limit: searchParams.get("limit") ?? undefined,
      product_id: searchParams.get("product_id") ?? undefined,
      movement_type: searchParams.get("movement_type") ?? undefined,
      date_from: searchParams.get("date_from") ?? undefined,
      date_to: searchParams.get("date_to") ?? undefined,
    });
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Query parameters failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await listStockMovements(tenantId, parsed.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
