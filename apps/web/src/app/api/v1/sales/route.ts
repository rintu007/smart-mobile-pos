import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { createSale } from "@/modules/pos/service";
import { createSaleRequestSchema } from "@/modules/pos/schema";
import { listSales } from "@/modules/sales-invoices/service";
import { listSalesQuerySchema } from "@/modules/sales-invoices/schema";

// docs/modules/pos/specification.md#4-api-contract (POST), docs/modules/sales-invoices/specification.md#4-api-contract
// (GET, Sprint 24). Route Handlers are thin: parse, validate, call exactly one service method,
// shape the response — docs/08-folder-structure/backend-structure.md §2.

export async function POST(request: NextRequest) {
  try {
    const { authUserId, tenantId } = await requirePermission(request, ["cashier", "manager", "owner"]);

    const body = await request.json();
    const parsed = createSaleRequestSchema.safeParse(body);
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Request body failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await createSale(authUserId, tenantId, parsed.data);
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
    const { tenantId, userId, role } = await requirePermission(request, ["cashier", "manager", "owner"]);

    const { searchParams } = new URL(request.url);
    const parsed = listSalesQuerySchema.safeParse({
      cursor: searchParams.get("cursor") ?? undefined,
      limit: searchParams.get("limit") ?? undefined,
      date_from: searchParams.get("date_from") ?? undefined,
      date_to: searchParams.get("date_to") ?? undefined,
    });
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Query parameters failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await listSales(tenantId, role, userId, parsed.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
