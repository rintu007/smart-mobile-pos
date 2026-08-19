import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { createCustomer, listCustomers } from "@/modules/customers/service";
import { createCustomerRequestSchema, listCustomersQuerySchema } from "@/modules/customers/schema";

// docs/modules/customers/specification.md#4-api-contract. Route Handlers are thin: parse,
// validate, call exactly one service method, shape the response —
// docs/08-folder-structure/backend-structure.md §2.

export async function POST(request: NextRequest) {
  try {
    const { authUserId, tenantId } = await requirePermission(request, ["cashier", "manager", "owner"]);

    const body = await request.json();
    const parsed = createCustomerRequestSchema.safeParse(body);
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Request body failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await createCustomer(authUserId, tenantId, parsed.data);
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
    const { tenantId } = await requirePermission(request, ["cashier", "manager", "owner"]);

    const { searchParams } = new URL(request.url);
    const parsed = listCustomersQuerySchema.safeParse({
      cursor: searchParams.get("cursor") ?? undefined,
      limit: searchParams.get("limit") ?? undefined,
      phone: searchParams.get("phone") ?? undefined,
    });
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Query parameters failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await listCustomers(tenantId, parsed.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
