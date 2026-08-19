import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";

// docs/11-api/rate-limiting.md §1/§2 — limits sized to stop a runaway client (a bug, a retry loop,
// a compromised device), never to constrain a real Cashier/Manager under normal operation.

// Cleanup runs on roughly 1 in 100 calls, not every call — an indexed DELETE is cheap, but there is
// no reason to pay it on every single request when the table only needs to stay roughly bounded,
// not exactly empty of expired rows at every instant.
const CLEANUP_PROBABILITY = 0.01;
const CLEANUP_RETENTION_MS = 60 * 60 * 1000;

/**
 * Fixed-window rate limit, backed by `rate_limit_buckets` (Postgres — no external service, per
 * this project's standing free/open-source-first constraint). Throws `429 RATE_LIMITED` with a
 * `Retry-After` header (docs/11-api/rate-limiting.md §2) when `scope` has been called more than
 * `limit` times within the current `windowSeconds`-wide window; otherwise returns silently.
 *
 * `scope` is the caller's own fully-resolved key (e.g. `read:tenant:<tenantId>`) — this function
 * never interprets it, only uses it as an opaque bucket identifier alongside the current window.
 */
export async function checkRateLimit(
  scope: string,
  limit: number,
  windowSeconds: number,
): Promise<void> {
  const now = Date.now();
  const windowMs = windowSeconds * 1000;
  const windowStartMs = Math.floor(now / windowMs) * windowMs;
  const windowEnd = new Date(windowStartMs + windowMs);
  const key = `${scope}|${windowStartMs}`;

  const bucket = await repository.incrementBucket(key, windowEnd);

  if (Math.random() < CLEANUP_PROBABILITY) {
    await repository.deleteExpiredBuckets(new Date(now - CLEANUP_RETENTION_MS));
  }

  if (bucket.count > limit) {
    const retryAfterSeconds = Math.max(1, Math.ceil((windowEnd.getTime() - now) / 1000));
    throw new ApiError(
      429,
      "RATE_LIMITED",
      "Too many requests.",
      { limit, retry_after_seconds: retryAfterSeconds },
      { "Retry-After": String(retryAfterSeconds) },
    );
  }
}
