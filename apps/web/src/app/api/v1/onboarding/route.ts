import { NextRequest, NextResponse } from "next/server";
import { requireAuthenticatedUser } from "@/core/auth/session";
import { ApiError } from "@/core/errors/api-error";
import { onboard } from "@/modules/identity/service";
import { onboardingRequestSchema } from "@/modules/identity/schema";

// docs/11-api/endpoints/identity.md#onboarding. Route Handlers are thin: parse, validate, call
// exactly one service method, shape the response — docs/08-folder-structure/backend-structure.md §2.

export async function POST(request: NextRequest) {
  const response = NextResponse.next();

  try {
    const { authUserId } = await requireAuthenticatedUser(request, response);

    const body = await request.json();
    const parsed = onboardingRequestSchema.safeParse(body);
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Request body failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await onboard(authUserId, parsed.data);
    return NextResponse.json(result, { status: 201, headers: response.headers });
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), {
        status: error.status,
        headers: response.headers,
      });
    }
    throw error;
  }
}
