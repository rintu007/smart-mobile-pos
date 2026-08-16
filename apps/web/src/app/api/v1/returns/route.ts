import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError } from "@/core/errors/api-error";
import { createReturn, listReturns } from "@/modules/returns/service";
import { createReturnRequestSchema, listReturnsQuerySchema } from "@/modules/returns/schema";

// docs/modules/returns/specification.md#4-api-contract. Route Handlers are thin: parse, validate,
// call exactly one service method, shape the response — docs/08-folder-structure/backend-structure.md §2.

export async function POST(request: NextRequest) {
  try {
    const { authUserId, tenantId } = await requirePermission(request, ["cashier", "manager", "owner"]);

    const body = await request.json();
    const parsed = createReturnRequestSchema.safeParse(body);
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Request body failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await createReturn(authUserId, tenantId, parsed.data);
    return NextResponse.json(result, { status: 201 });
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}

export async function GET(request: NextRequest) {
  try {
    const { tenantId, userId, role } = await requirePermission(request, [
      "cashier",
      "manager",
      "owner",
    ]);

    const { searchParams } = new URL(request.url);
    const parsed = listReturnsQuerySchema.safeParse({
      cursor: searchParams.get("cursor") ?? undefined,
      limit: searchParams.get("limit") ?? undefined,
      status: searchParams.get("status") ?? undefined,
    });
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Query parameters failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await listReturns(tenantId, role, userId, parsed.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}
