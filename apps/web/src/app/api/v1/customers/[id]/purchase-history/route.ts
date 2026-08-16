import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError } from "@/core/errors/api-error";
import { getPurchaseHistory } from "@/modules/customers/service";
import { purchaseHistoryQuerySchema } from "@/modules/customers/schema";

// docs/modules/customers/specification.md#4-api-contract — GET /customers/{id}/purchase-history.
// A static child route under the dynamic `[id]/`, matching Sprint 23/24's own
// static-vs-dynamic routing lesson (docs/08-folder-structure/backend-structure.md §2).

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const { tenantId } = await requirePermission(request, ["cashier", "manager", "owner"]);
    const { id } = await params;

    const { searchParams } = new URL(request.url);
    const parsed = purchaseHistoryQuerySchema.safeParse({
      cursor: searchParams.get("cursor") ?? undefined,
      limit: searchParams.get("limit") ?? undefined,
    });
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Query parameters failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await getPurchaseHistory(tenantId, id, parsed.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}
