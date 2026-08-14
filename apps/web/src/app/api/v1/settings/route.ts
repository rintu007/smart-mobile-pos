import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError } from "@/core/errors/api-error";
import { getSettings, updateSettings } from "@/modules/settings/service";
import { updateSettingsRequestSchema } from "@/modules/settings/schema";

// docs/modules/settings/specification.md#4-api-contract. Route Handlers are thin: parse, validate,
// call exactly one service method, shape the response — docs/08-folder-structure/backend-structure.md §2.

export async function GET(request: NextRequest) {
  try {
    const { tenantId, role } = await requirePermission(request, ["cashier", "manager", "owner"]);

    const result = await getSettings(tenantId, role);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}

export async function PATCH(request: NextRequest) {
  try {
    const { tenantId } = await requirePermission(request, ["owner"]);

    const body = await request.json();
    const parsed = updateSettingsRequestSchema.safeParse(body);
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Request body failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await updateSettings(tenantId, parsed.data);
    return NextResponse.json(result);
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}
