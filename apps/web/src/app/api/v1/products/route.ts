import { NextRequest, NextResponse } from "next/server";
import { requireSession } from "@/core/auth/session";
import { ApiError } from "@/core/errors/api-error";
import { createProduct } from "@/modules/products/service";
import { createProductRequestSchema } from "@/modules/products/schema";

// docs/modules/products/specification.md#4-api-contract. Route Handlers are thin: parse, validate,
// call exactly one service method, shape the response — docs/08-folder-structure/backend-structure.md §2.

export async function POST(request: NextRequest) {
  try {
    const { authUserId, tenantId } = await requireSession(request);

    const body = await request.json();
    const parsed = createProductRequestSchema.safeParse(body);
    if (!parsed.success) {
      throw new ApiError(422, "VALIDATION_FAILED", "Request body failed validation.", {
        issues: parsed.error.issues,
      });
    }

    const result = await createProduct(authUserId, tenantId, parsed.data);
    return NextResponse.json(result, { status: 201 });
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(error.toResponseBody(), { status: error.status });
    }
    throw error;
  }
}
