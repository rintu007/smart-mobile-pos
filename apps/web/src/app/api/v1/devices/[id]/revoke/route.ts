import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { revokeDevice } from "@/modules/devices/service";

// docs/11-api/endpoints/identity.md#devices, docs/11-api/authentication.md §5 — Owner only.
// Irreversible via this endpoint: a revoked device never un-revokes, it re-registers as a new one
// (a fresh `client_device_id`, docs/07-database/identifiers.md §4). No request body — the target
// id travels via the URL, same shape as customers' own `[id]/erase/route.ts`.

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const { tenantId, userId } = await requirePermission(request, ["owner"]);
    const { id } = await params;

    const result = await revokeDevice(tenantId, id, userId);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
