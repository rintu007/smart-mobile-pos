import { describe, expect, it } from "vitest";
import { ApiError } from "./api-error";

describe("ApiError", () => {
  it("produces the standard error envelope shape from docs/11-api/api-principles.md §6", () => {
    const error = new ApiError(401, "UNAUTHENTICATED", "No valid session token presented.");

    expect(error.toResponseBody()).toEqual({
      error: {
        code: "UNAUTHENTICATED",
        message: "No valid session token presented.",
      },
    });
  });

  it("includes details only when provided, never as an empty object", () => {
    const withoutDetails = new ApiError(404, "NOT_FOUND", "No sale found.");
    const withDetails = new ApiError(422, "VALIDATION_FAILED", "Invalid quantity.", {
      field: "quantity",
    });

    expect(withoutDetails.toResponseBody().error).not.toHaveProperty("details");
    expect(withDetails.toResponseBody().error.details).toEqual({ field: "quantity" });
  });
});
