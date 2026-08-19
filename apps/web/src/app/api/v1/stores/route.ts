import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { listStores } from "@/modules/stores/service";

// docs/modules/company-store-setup/specification.md#4-api-contract,
// docs/11-api/endpoints/identity.md#stores. Route Handlers are thin: parse, validate, call exactly
// one service method, shape the response — docs/08-folder-structure/backend-structure.md §2.

export async function GET(request: NextRequest) {
  try {
    const { tenantId } = await requirePermission(request, ["cashier", "manager", "owner"]);

    const stores = await listStores(tenantId);
    // No pagination needed in practice (ADR-0003: exactly one store per tenant in V1), but the
    // envelope still matches api-principles.md §4's list-endpoint shape for consistency.
    return NextResponse.json({ data: stores, next_cursor: null });
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
