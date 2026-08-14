import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError } from "@/core/errors/api-error";
import { getSaleDetail } from "@/modules/sales-invoices/service";

// docs/modules/sales-invoices/specification.md#4-api-contract. Route Handlers are thin: parse,
// validate, call exactly one service method, shape the response —
// docs/08-folder-structure/backend-structure.md §2. A static sibling of `sales/lookup/route.ts`,
// not a shared file — Sprint 23's own live-found routing bug (`/users/invite` resolving to
// `users/[id]`) is why `lookup` gets its own static route instead of risking the same collision.

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const { tenantId } = await requirePermission(request, ["cashier", "manager", "owner"]);
    const { id } = await params;

    const result = await getSaleDetail(tenantId, id);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}
