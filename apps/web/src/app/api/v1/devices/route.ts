import { NextRequest, NextResponse } from "next/server";
import { requirePermission } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import { listDevices } from "@/modules/devices/service";

// docs/11-api/endpoints/identity.md#devices — the device-revocation UI list, Owner only. No
// cursor pagination — a real shop's device count is small (a handful of tills/phones), unlike
// products or sales, so a plain unpaginated list matches the actual scale this needs to handle.

export async function GET(request: NextRequest) {
  try {
    const { tenantId } = await requirePermission(request, ["owner"]);

    const devices = await listDevices(tenantId);
    return NextResponse.json({ data: devices });
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
