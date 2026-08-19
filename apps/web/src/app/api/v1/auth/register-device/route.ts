import { NextRequest, NextResponse } from "next/server";
import { requireAuthenticatedUser } from "@/core/auth/session";
import { ApiError, errorResponse } from "@/core/errors/api-error";
import * as identityService from "@/modules/identity/service";
import { registerDevice } from "@/modules/devices/service";
import { registerDeviceRequestSchema } from "@/modules/devices/schema";

// docs/11-api/endpoints/identity.md#devices, docs/11-api/authentication.md §2 — "the
// connectivity-establishing call itself": any authenticated user, no `tenant_id` claim required
// (matching onboarding's own use of `requireAuthenticatedUser`, not `requireSession`), since this
// is the one call every subsequent request depends on having already succeeded once per install.

export async function POST(request: NextRequest) {
  try {
    const { authUserId } = await requireAuthenticatedUser(request);

    const body = await request.json();
    const parsed = registerDeviceRequestSchema.safeParse(body);
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Request body failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const userId = await identityService.resolveUserId(authUserId);
    const result = await registerDevice(userId, parsed.data.client_device_id);
    return NextResponse.json(result, { status: 201 });
  } catch (error) {
    if (error instanceof ApiError) {
      return errorResponse(error);
    }
    throw error;
  }
}
