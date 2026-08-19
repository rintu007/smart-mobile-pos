import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { eraseCustomer } from "@/modules/customers/service";

// docs/modules/customers/specification.md#4-api-contract, docs/12-security/privacy.md §4.
// A static child of `[id]/`, sibling of `../route.ts` — no dynamic segment at this nesting level,
// so no collision risk (the same shape returns' `[id]/approve/route.ts` already established). No
// request body — the target id travels via the URL, and there's nothing else to supply: an erasure
// request has no partial form, it either anonymises the row or it's a no-op replay of one already
// done.

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    // Owner-only — stricter than DELETE's Manager+Owner (a data-governance action, not an ordinary
    // back-office one), per this endpoint's own docstring in customers/service.ts.
    const { tenantId } = await requirePermission(request, ["owner"]);
    const { id } = await params;

    const result = await eraseCustomer(tenantId, id);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
