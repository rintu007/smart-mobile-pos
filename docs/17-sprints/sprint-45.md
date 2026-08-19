# Sprint 45

> **Dates:** 2026-08-19 – 2026-08-19 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item — closes finding #2 from Sprint 43's OWASP checklist review)
> **Status:** Closed.

## Goal

Close the second of Sprint 43's two flagged findings that carried real, unmitigated risk: rate
limiting, fully specified in [rate-limiting.md](../11-api/rate-limiting.md) since Phase 11, was
entirely unimplemented — confirmed by grep, zero hits for `rate.?limit|throttle` anywhere in
`apps/web/src`. Unlike the RLS finding (the other flagged item, deliberately left for the founder
since a wrong fix risks a production outage), this one has no such risk — it's pure additive
capability, safe to build without any production-configuration ambiguity.

## Design decisions, found while writing the spec

1. **The "Auth" endpoint class cannot be implemented in this codebase at all — a real
   architectural gap, not just an unimplemented feature.** Sign-in is a direct client call to
   Supabase Auth (`docs/modules/authentication/specification.md` §1a: "the first real Flutter
   screen... calls Supabase Auth directly"), never reaching an `apps/web` Route Handler. There is no
   request here to attach a rate limit to. `identity-and-sessions.md §6`'s "repeated failed sign-in
   attempts are throttled per-account and per-IP" claim can only ever be made true by Supabase
   Auth's own platform-side configuration — a project setting, not code this repository can add.
   Whether that setting is actually active was never separately confirmed and remains a real, named
   gap.
2. **The remaining 3 classes (mutating, read, sync-push) were built as a Postgres-backed
   fixed-window counter, not an external service** (Upstash Redis or similar) — consistent with this
   project's standing free/open-source-first constraint, the same reasoning that already chose
   Dependabot over a paid scanner. A new `rate_limit_buckets` table (no `tenant_id`, no RLS — it
   carries no tenant-owned data, only an opaque scope key already resolved from an authenticated
   session before it's ever touched).
3. **Enforced inside `core/auth/session.ts`'s `requirePermission`**, the one function nearly every
   Route Handler already calls to resolve its session, rather than Vercel edge middleware or
   per-route duplication — no individual endpoint needs to remember to add it, and the ~30 existing
   call sites needed zero changes (the class defaults from the HTTP method: `GET` → read, otherwise
   → mutating; only `POST /sync/push` needed an explicit override to the tighter `sync-push` class).
4. **`429 RATE_LIMITED` needed a real `Retry-After` HTTP header**, per `rate-limiting.md §2` — the
   first error in this codebase's history to need an actual response header, not only a body field.
   `ApiError` gained an optional `headers` field, and a new shared `errorResponse()` helper
   (`core/errors/api-error.ts`) replaced the identical two-line
   `NextResponse.json(error.toResponseBody(), { status: error.status })` pattern that had been
   copy-pasted into all 32 Route Handler files — a mechanical, single-pattern find-replace across
   all of them (confirmed textually identical beforehand), not 32 individually-reasoned edits.
5. **A real, previously-unchecked documentation drift found in the same pass**: `rate-limiting.md`
   §1 claimed the sync push batch cap was 500 operations; `sync/schema.ts`'s `syncPushRequestSchema`
   has actually enforced `.max(200)` since Sprint 13. Corrected to match the code, not the other way
   around — the code was never wrong, the row had simply never been checked against it.

## Capacity check

No estimate was carried in the backlog for this item, since it was not a planned backlog line — a
same-day fix of a specific, already-flagged Sprint 43 finding, the same shape Sprint 44's
release-checklist reconciliation took.

## Reserved capacity

- [x] Defect capacity reserved: this closes a real, previously-flagged gap (Sprint 43 finding #2),
      not new discretionary scope.

## Risks

- **None for production data** — purely additive: a new table, a new module, one new parameter on
  an existing function with a safe default, and a mechanical response-shaping change. No existing
  behaviour changes for any request that stays under its class's limit (every real Cashier/Manager
  workflow, by rate-limiting.md's own stated design intent).
- **The Auth-class gap (design decision #1) remains real and unmitigated** — named here and in
  `owasp-checklist.md`/`rate-limiting.md`, not silently dropped. Confirming Supabase Auth's own
  platform-side throttling is a founder-accessible dashboard check, not an engineering task this
  session can perform blind.

## Definition of Done

- [x] `apps/web/prisma/schema.prisma` + migration — `RateLimitBucket` model
      (`rate_limit_buckets`), no `tenant_id`/RLS (documented why in the model's own comment).
- [x] `core/rate-limit/repository.ts` + `service.ts` — the fixed-window counter, with opportunistic
      (1%-probability) cleanup of expired buckets so the table stays bounded without a scheduled job.
- [x] `core/errors/api-error.ts` — `ApiError.headers` + `errorResponse()` helper.
- [x] All 32 Route Handler files — mechanically updated to use `errorResponse()`, carrying any
      future error's headers (not just `RATE_LIMITED`'s) without needing individual changes again.
- [x] `core/auth/session.ts`'s `requirePermission` — the three implementable classes wired in,
      HTTP-method-inferred default, `POST /sync/push` given its explicit tighter class.
- [x] `apps/web/integration-tests/rate-limit.test.ts` — 4 cases against a real Postgres connection:
      limit enforcement, `Retry-After` correctness, scope isolation, window reset.
- [x] `apps/web/src/core/errors/api-error.test.ts` — 2 new cases for `errorResponse()`'s header
      behaviour.
- [x] Verified locally: full `test:integration` (90/90, 86 pre-existing + 4 new), full unit suite
      (211/211, 209 pre-existing + 2 new), `tsc`/`eslint` clean.
- [x] `rate-limiting.md`, `owasp-checklist.md` corrected — the Auth-class architectural gap named,
      the 500→200 batch-cap drift fixed, A07's status and the summary gap-count updated.
- [x] implementation-log, `docs/README.md` updated in the same PR.

## Demo script

**Local, run 2026-08-19**, mirroring `pr.yml`'s `fast-integration` job exactly:

1. Fresh migration applied (`rate_limit_buckets` created). ✅
2. `pnpm --filter @smart-pos/web test:integration` → 90/90 passing (86 pre-existing + 4 new rate-limit
   cases: exhausting a 5-call/60s limit on the 6th call, a correct `Retry-After` value bounded by the
   window, two scopes never sharing a bucket, and a 1-second window genuinely resetting after it
   elapses). ✅
3. `tsc --noEmit`/`eslint .`/`pnpm test` (211/211, 209 pre-existing + 2 new) all clean. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this surfaces a concrete process
change — not pre-judged here. Worth naming regardless: closing Sprint 43's two flagged findings
took two different shapes for a reason — this one was safe to build immediately because it carried
no production-configuration ambiguity, while the RLS finding remains open specifically because it
does. The same "found a real gap" moment can call for two different responses depending on whether
fixing it blind is actually safe, and telling those apart correctly matters as much as finding the
gap in the first place.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-19 | Sprint 45: mutating/read/sync-push rate limiting built (Postgres-backed fixed-window counter, `requirePermission`, no external service), closing Sprint 43's finding #2. Found the Auth class is architecturally unreachable from this codebase — a real gap, named not faked. Found and corrected a real 500-vs-200 sync-push-batch-cap drift. `owasp-checklist.md`/`rate-limiting.md` corrected; 90/90 integration checks, 211/211 unit tests. |
