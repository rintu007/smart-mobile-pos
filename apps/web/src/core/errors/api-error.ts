// The one error envelope shape used by every endpoint, per docs/11-api/api-principles.md §6 and
// the full code namespace in docs/11-api/error-catalogue.md. `code` is what clients switch on;
// `message` is log-facing only and is never parsed by a client.

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
    public readonly details?: Record<string, unknown>,
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
