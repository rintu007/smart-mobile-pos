import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError } from "@/core/errors/api-error";
import { lookupSale } from "@/modules/sales-invoices/service";
import { lookupSaleQuerySchema } from "@/modules/sales-invoices/schema";

// docs/modules/sales-invoices/specification.md#4-api-contract. Route Handlers are thin: parse,
// validate, call exactly one service method, shape the response —
// docs/08-folder-structure/backend-structure.md §2. A static sibling of `sales/[id]/route.ts`,
// built as its own static path from the start — Next.js would otherwise resolve `/sales/lookup`
// to `sales/[id]` with `id: "lookup"`, the exact routing bug Sprint 23 found live for
// `/users/invite`.

export async function GET(request: NextRequest) {
  try {
    const { tenantId } = await requirePermission(request, ["cashier", "manager", "owner"]);

    const { searchParams } = new URL(request.url);
    const parsed = lookupSaleQuerySchema.safeParse({
      provisional_invoice_number: searchParams.get("provisional_invoice_number") ?? undefined,
      canonical_invoice_number: searchParams.get("canonical_invoice_number") ?? undefined,
    });
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Query parameters failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await lookupSale(tenantId, parsed.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}
