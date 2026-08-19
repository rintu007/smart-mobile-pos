import { NextResponse } from "next/server";

// The one error envelope shape used by every endpoint, per docs/11-api/api-principles.md §6 and
// the full code namespace in docs/11-api/error-catalogue.md. `code` is what clients switch on;
// `message` is log-facing only and is never parsed by a client.

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
    public readonly details?: Record<string, unknown>,
    // Added Sprint 45 (rate-limiting.md §2) — `RATE_LIMITED`'s `Retry-After` is the first (and so
    // far only) error this codebase needs an actual HTTP header for, not just a body field.
    public readonly headers?: Record<string, string>,
  ) {
    super(message);
    this.name = "ApiError";
  }

  toResponseBody() {
    return {
      error: {
        code: this.code,
        message: this.message,
        ...(this.details ? { details: this.details } : {}),
      },
    };
  }
}

// Every Route Handler's catch block builds this same response — centralised here (Sprint 45) so
// the one error type that needs response headers (`RATE_LIMITED`'s `Retry-After`) doesn't require
// every one of the ~30 call sites to know about `error.headers` individually.
export function errorResponse(error: ApiError): NextResponse {
  return NextResponse.json(error.toResponseBody(), {
    status: error.status,
    ...(error.headers ? { headers: error.headers } : {}),
  });
}
