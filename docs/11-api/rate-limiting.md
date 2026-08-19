# Rate Limiting

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.2.1
> **Last updated:** 2026-08-20
> **Owner:** Principal Next.js Engineer / DevOps
> **Approved by:** _pending_

Limits per endpoint class and per tenant, plus the connection-pooling design that closes this
phase's exit criterion tied to [risk R-07](../01-vision/risks-constraints-assumptions.md)
(serverless connection exhaustion). Limits here are sized to stop a *runaway client* (a bug, a
retry loop, a compromised device), never to constrain a real Cashier or Manager — a limit a
legitimate user could plausibly hit during normal operation is a limit set wrong.

---

## 1. Limits by endpoint class

**Corrected Sprint 45 (found while implementing, not by inspection):** the sync push batch cap is
**200**, not 500 — `sync/schema.ts`'s `syncPushRequestSchema` has enforced `.max(200)` since Sprint
13; this row had simply never been checked against the code that already existed. "Per device"
below is implemented as **per authenticated user** (`authUserId`) for the two classes actually built
— no `devices` table existed anywhere in this schema (`tenant-isolation.md`'s already-named gap at
the time), the same substitution Sprint 26 (Trading Day) and Sprint 41 (`seed-second-user.ts`)
already made for the identical missing dimension.

**Status, 2026-08-20:** `devices` now exists (Sprint 55). This substitution is left unchanged here,
not silently revisited — a genuine per-device rate limit is real, separately-scoped follow-up work
(deciding whether shared-till multi-user devices change the right scope, and whether the existing
per-user limits are even too generous/strict once device-level counting is possible), named rather
than assumed automatically correct now that the table exists.

| Class | Scope | Limit | Rationale | Status |
| --- | --- | --- | --- | --- |
| Auth (`/auth/*` sign-in, OTP request) | Per account, and separately per IP | 5 sign-in attempts/minute per account; 20 OTP requests/hour per account; 30 requests/minute per IP | Brute-force and OTP-spam resistance — sized against attack patterns, not legitimate use, which never approaches this. | **Cannot be implemented in this codebase.** Sign-in is a direct client call to Supabase Auth (`docs/modules/authentication/specification.md` §1a) — it never reaches an `apps/web` Route Handler, so there is no request here to attach a limit to. This needs Supabase Auth's own platform-side rate limiting (a project-configuration setting, not code); whether it's already active by default has not been separately confirmed. |
| Sync push (`/sync/push`) | Per device (per user) | 1 push per 5 seconds; push batch capped at **200** operations (corrected) | A device legitimately syncs in bursts on reconnect, not continuously — this bounds a misbehaving client from hammering the endpoint in a tight loop, not normal opportunistic syncing per [sync-api.md §7](sync-api.md#7-what-triggers-a-sync-cycle). | **Built, Sprint 45** — `requirePermission`'s `"sync-push"` class. |
| Sync pull (`/sync/pull`) | Per tenant | Falls under the generic read-endpoint limit below; pull page capped at 200 rows | This table never gave pull its own numeric per-minute figure, only the already-schema-enforced page-size cap — no separate class was actually specified beyond "read." | Page cap already enforced (Zod, since Sprint 13); the generic read limit applies, **built Sprint 45**. |
| Mutating endpoints (`/sales`, `/returns`, `/stock-movements`, etc.) | Per device (per user) | 60 requests/minute | Far above any realistic human cashier throughput ([tap-count-audit.md](../09-navigation/tap-count-audit.md)'s fastest workflow, WF-002, still takes several seconds of real interaction) — this catches a buggy retry loop, not a fast till. | **Built, Sprint 45** — `requirePermission`'s default class for any non-`GET` request. |
| Read endpoints (`/products`, `/sales`, reports) | Per tenant | 300 requests/minute | Sized with headroom above [cost-model.md](../02-business-requirements/cost-model.md)'s realistic per-shop transaction assumptions at the scale that document models; protects shared infrastructure from one runaway tenant affecting others on the shared-schema platform ([ADR-0004](../adr/ADR-0004-shared-schema-multi-tenancy.md)). | **Built, Sprint 45** — `requirePermission`'s default class for any `GET` request. |

## 2. Response on limit exceeded

`429`, error code `RATE_LIMITED` (per [error-catalogue.md](error-catalogue.md)), with a
`Retry-After` header stating the number of seconds until the limit resets — the client backs off
for that duration rather than retrying immediately, which would only extend the block.

## 3. Connection pooling — the R-07 mitigation, load-tested before GA

Per this phase's exit criterion, connection pooling must be **configured and load-tested at 10×
expected peak**, not merely present. The concrete design:

- **Supabase's built-in pooler (Supavisor), in transaction mode**, sits between Vercel's serverless
  Route Handler instances and PostgreSQL — free, included with the Supabase project, requiring no
  additional paid service, consistent with this project's free/open-source-first constraint.
- Prisma is configured with **two** connection strings: a pooled URL (transaction mode, used for
  all runtime queries from Route Handlers) and a direct URL (used only for migrations, which need a
  session-mode connection that transaction-mode pooling cannot support). This two-URL split is
  Prisma's documented pattern for serverless-plus-pooler deployments; the exact environment-variable
  naming is confirmed against current Prisma/Supabase documentation at Phase 18, per this
  documentation set's standing practice of not committing to unverified tool specifics ahead of
  implementation.
- **Load test target:** expected peak concurrent connections at V1's modelled scale
  ([cost-model.md](../02-business-requirements/cost-model.md)) × 10, run against a staging Supabase
  project before the first commercial (non-free-tier) launch — tracked as a Phase 14 (Testing
  Strategy) test plan item and a Phase 16 milestone gate, not something this documentation phase can
  execute itself.

## 4. Implementation, decided Sprint 45

Enforced inside `core/auth/session.ts`'s `requirePermission` — the one function nearly every Route
Handler already calls to resolve its session — rather than Vercel edge middleware or per-route
duplication, so no individual endpoint needs to remember to add it. The counter itself is a
Postgres-backed fixed-window bucket (`rate_limit_buckets`, one row per `(scope, window)`), not an
external service (Upstash Redis or similar) — consistent with this project's standing
free/open-source-first constraint (the same reasoning that chose Dependabot over a paid scanner).
`429 RATE_LIMITED` carries both a `Retry-After` HTTP header and the same figure in the JSON body's
`details.retry_after_seconds`, via a new `ApiError.headers` field and a shared `errorResponse()`
helper (`core/errors/api-error.ts`) — the first error in this codebase that needed a real header,
not only a body field.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial rate limits by endpoint class; Supavisor transaction-mode pooling design with the 10× load-test requirement tracked forward to Phase 14/16. |
| 0.2.0 | 2026-08-19 | Sprint 45 — mutating/read/sync-push classes built (Postgres-backed fixed-window counter in `requirePermission`, no external service). Corrected the sync push batch cap (200, not 500 — the code has said 200 since Sprint 13). Found and named a real architectural gap: the Auth class cannot be implemented in this codebase at all, since sign-in is a direct client call to Supabase Auth that never reaches an `apps/web` Route Handler — needs Supabase's own platform-side configuration, not code. "Per device" implemented as "per user," the same substitution already established elsewhere for the missing `devices` table. |
| 0.2.1 | 2026-08-20 | Status update: `devices` now exists (Sprint 55). The per-user substitution is left unchanged, named as real, separately-scoped follow-up work rather than silently revisited. |
