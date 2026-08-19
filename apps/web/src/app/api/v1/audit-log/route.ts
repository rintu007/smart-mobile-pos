import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { listAuditLog } from "@/modules/audit-log/service";
import { listAuditLogQuerySchema } from "@/modules/audit-log/schema";

// docs/11-api/endpoints/identity.md#audit-log. Route Handlers are thin: parse, validate, call
// exactly one service method, shape the response — docs/08-folder-structure/backend-structure.md §2.

export async function GET(request: NextRequest) {
  try {
    const { tenantId } = await requirePermission(request, ["manager", "owner"]);

    const { searchParams } = new URL(request.url);
    const parsed = listAuditLogQuerySchema.safeParse({
      cursor: searchParams.get("cursor") ?? undefined,
      limit: searchParams.get("limit") ?? undefined,
      entity_type: searchParams.get("entity_type") ?? undefined,
      entity_id: searchParams.get("entity_id") ?? undefined,
      date_from: searchParams.get("date_from") ?? undefined,
      date_to: searchParams.get("date_to") ?? undefined,
    });
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Query parameters failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await listAuditLog(tenantId, parsed.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
