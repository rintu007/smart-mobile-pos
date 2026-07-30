# Rate Limiting

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Principal Next.js Engineer / DevOps
> **Approved by:** _pending_

Limits per endpoint class and per tenant, plus the connection-pooling design that closes this
phase's exit criterion tied to [risk R-07](../01-vision/risks-constraints-assumptions.md)
(serverless connection exhaustion). Limits here are sized to stop a *runaway client* (a bug, a
retry loop, a compromised device), never to constrain a real Cashier or Manager — a limit a
legitimate user could plausibly hit during normal operation is a limit set wrong.

---

## 1. Limits by endpoint class

| Class | Scope | Limit | Rationale |
| --- | --- | --- | --- |
| Auth (`/auth/*` sign-in, OTP request) | Per account, and separately per IP | 5 sign-in attempts/minute per account; 20 OTP requests/hour per account; 30 requests/minute per IP | Brute-force and OTP-spam resistance — sized against attack patterns, not legitimate use, which never approaches this. |
| Sync push/pull (`/sync/*`) | Per device | 1 push per 5 seconds; push batch capped at 500 operations; pull page capped at 200 rows | A device legitimately syncs in bursts on reconnect, not continuously — this bounds a misbehaving client from hammering the endpoint in a tight loop, not normal opportunistic syncing per [sync-api.md §7](sync-api.md#7-what-triggers-a-sync-cycle). |
| Mutating endpoints (`/sales`, `/returns`, `/stock-movements`, etc.) | Per device | 60 requests/minute | Far above any realistic human cashier throughput ([tap-count-audit.md](../09-navigation/tap-count-audit.md)'s fastest workflow, WF-002, still takes several seconds of real interaction) — this catches a buggy retry loop, not a fast till. |
| Read endpoints (`/products`, `/sales`, reports) | Per tenant | 300 requests/minute | Sized with headroom above [cost-model.md](../02-business-requirements/cost-model.md)'s realistic per-shop transaction assumptions at the scale that document models; protects shared infrastructure from one runaway tenant affecting others on the shared-schema platform ([ADR-0004](../adr/ADR-0004-shared-schema-multi-tenancy.md)). |

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

## 4. What this document does not decide

Whether rate limiting is enforced at the edge (Vercel/Next.js middleware) or inside each Route
Handler is an implementation detail for Phase 18 — this document fixes the limits and their
rationale, which are the parts a later phase should not silently redefine.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial rate limits by endpoint class; Supavisor transaction-mode pooling design with the 10× load-test requirement tracked forward to Phase 14/16. |
