# Sprint 55

> **Dates:** 2026-08-20 – 2026-08-20 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item — server half only, closes Sprint 43's OWASP finding for `authorisation-model.md
> §2`'s device-revocation step)
> **Status:** Closed (server half). Mobile wiring is real, separately-scoped follow-up work,
> deliberately not built in this same sprint — see Risks below for why.

## Goal

Sprint 43's OWASP checklist review flagged `authorisation-model.md §2`'s step 2 (device revocation)
as a real, unaddressed gap — `core/auth/session.ts`'s own docstring said plainly "those tables
don't exist." Fully designed already (`schema-server.md`'s `devices` table, `authentication.md
§2/§4/§5`, `identity.md`'s endpoint table) but never built. This sprint builds exactly what was
already designed, resolving the one genuinely unspecified detail (how `client_device_id` is
presented on each request) as a dated correction, and verifies it against a real Postgres
connection with the same RLS deliberate-break-and-fix rigor Sprint 40 established.

## What was found while investigating scope, before writing any code

1. **`trading-day/specification.md §1` had already anticipated this exact moment.** Its own
   Sprint-26 text named `devices` not existing as the reason `trading_days` uses `(tenant_id,
   store_id)` scoping instead of per-device, and said explicitly: "Revisit when Authentication's
   device-registration slice lands... not before." `tenant-isolation.md §2`'s "devices was
   explicitly dropped as a named, dated deviation" phrasing (found first, and briefly concerning)
   turned out to describe the same thing from the RLS-checklist's point of view — a table that
   didn't exist yet, not a permanently abandoned concept. Read primary sources directly before
   treating either as a reason to stop.
2. **No existing automated test — unit or integration — exercises `requireSession`/
   `requirePermission` at all.** Confirmed by grep across the whole repo: every existing
   integration test either tests RLS via raw Postgres (`cross-tenant-isolation.test.ts`) or calls
   service-layer functions directly (`sync-idempotent-replay.test.ts` etc.), bypassing the HTTP/
   auth layer entirely. This meant adding a hard per-request check inside `requireSession` carried
   **zero risk of breaking any existing automated test** — verified by actually running the full
   suite, not assumed from the grep alone.
3. **A real production-rollout risk, found before merging anything.** The corollary of finding 2:
   this hard check *would* immediately reject every real API call from any currently-installed
   mobile build the moment it deploys, since no such build knows to call the new register-device
   endpoint or send the new header yet. Confirmed with the founder before proceeding — no live
   reliance on the current backend today, so shipping the server half now and the mobile half as
   the very next piece is safe. Named explicitly rather than assumed either way.

## Design decisions

1. **`id` is server-generated, not client-generated** — a deliberate, reasoned exception to
   `schema-server.md`'s own blanket "every table has a client-generated id" convention, matching
   the precedent `invoice_sequences` already set for a row no offline client write ever creates
   directly. `client_device_id` (a separate column) is the actual client-generated, dedup-key
   field ADR-0007 concerns itself with.
2. **`X-Device-Id`, a new custom header — the first this codebase has ever needed.** `authentication.md
   §4` never specified exactly how `client_device_id` is "presented" on each request. A Custom
   Access Token Hook claim (matching `tenant_id`'s own injection) was considered and rejected: a
   newly-registered device's id isn't known at token-mint time, since register-device is itself the
   call that creates the row, necessarily after the token already exists.
3. **A missing header and a genuinely revoked device both throw the identical `401 DEVICE_REVOKED`**
   — no separate code for "never registered" vs. "since revoked," since the mobile client's own
   response to either is the same (force a local sign-out, never touch the unsynced sales queue,
   `authentication.md §5`).
4. **`revokeDevice` is idempotent on an already-revoked device** — returns the existing terminal
   state rather than erroring or re-stamping, the same shape `customers/service.ts`'s
   `eraseCustomer` already established for an analogous irreversible action.
5. **`devices` joins the existing "parent-join" RLS category, not a new one.** `tenant-isolation.md
   §2`'s own category is generic to "joins through a parent table with no own `tenant_id` column" —
   `devices` joining via `users` instead of `sales`/`returns` doesn't need a new category, just a
   new row in the same one.
6. **Mobile wiring deliberately out of scope for this same sprint** — a register-device call,
   a `client_device_id` generated and persisted locally, an `X-Device-Id` header on every request,
   and handling `DEVICE_REVOKED` by forcing sign-out are all real, separately-scoped mobile-side
   work, tracked as the direct next piece rather than compressed into this sprint under time
   pressure.

## Capacity check

No estimate carried in the backlog — a same-day gap closure, not a planned backlog line, but the
largest single-sprint scope since the M4 backlog items themselves (a new table, RLS policy, 3
endpoints, a session-layer wiring change, and an extension to the cross-tenant isolation suite).

## Reserved capacity

- [x] Defect capacity reserved: this closes a real, previously-named gap (Sprint 43's OWASP finding
      for `authorisation-model.md §2`), not new discretionary scope.

## Risks

**Real, and reasoned through explicitly, not assumed away.** Unlike every other cross-cutting fix
in this run of sprints, this one changes what every authenticated API request requires. Confirmed
with the founder before merging (see finding 3 above) that no live reliance on today's backend
exists, making it safe to ship now with mobile wiring following as the next piece rather than
bundled atomically. Had the answer been different, the right call would have been to ship the
`devices` table/endpoints without wiring the `requireSession` enforcement yet — named here as the
fallback that wasn't needed, not silently omitted from consideration.

## Definition of Done

- [x] `apps/web/prisma/schema.prisma` — `Device` model (server-generated `id`, `clientDeviceId`,
      `lastSeenAt`, `revokedAt`, `revokedBy`, `createdAt`/`createdBy`; no direct `tenantId`).
      Migration `20260819203250_add_devices` generated and applied.
- [x] `supabase/sql/019_rls_devices.sql` — parent-join RLS via `users`, the same template
      `017_`/`018_` already established.
- [x] `apps/web/src/modules/devices/{schema,repository,service}.ts` — `registerDevice` (upsert on
      `(user_id, client_device_id)`), `listDevices`, `revokeDevice` (idempotent), `assertDeviceUsable`
      (fail-closed: missing header, unregistered, or revoked all reject identically).
- [x] `apps/web/src/app/api/v1/auth/register-device/route.ts` (POST, `requireAuthenticatedUser`),
      `apps/web/src/app/api/v1/devices/route.ts` (GET, Owner), `apps/web/src/app/api/v1/devices/[id]/revoke/route.ts`
      (PATCH, Owner).
- [x] `apps/web/src/core/auth/session.ts` — `requireSession` now resolves the internal `userId` and
      calls `assertDeviceUsable` (reading `X-Device-Id`) before returning; `requirePermission`'s
      docstring corrected (steps 1/2/3 all implemented, not just 1/3).
- [x] `apps/web/src/modules/devices/service.test.ts` (NEW, 9 cases) — formatting, idempotent
      revocation, and every `assertDeviceUsable` branch.
- [x] `apps/web/integration-tests/setup/seed-tenant.ts` — seeds one `devices` row per tenant, the
      same fixture shape every other table already gets.
- [x] `apps/web/integration-tests/cross-tenant-isolation.test.ts` — `devices` added to the
      `TABLES` array (parent-join category); doc comment's table count corrected (20 of 20, not 19).
- [x] Verified locally: `tsc`/`eslint` clean; `vitest run` 227/227 unit tests (218 pre-existing + 9
      new); `vitest run --config vitest.integration.config.ts` 98/98 (94 pre-existing + 4 new — a
      full RLS-table cycle: read/update/delete negative + positive control).
- [x] RLS verified the same way Sprint 40 set precedent: `019_rls_devices.sql` deliberately
      disabled, suite fails (exactly the 3 `devices` cross-tenant cases), re-enabled, suite passes
      98/98 again.
- [x] `docs/07-database/schema-server.md`, `docs/11-api/authentication.md`,
      `docs/11-api/endpoints/identity.md`, `docs/11-api/error-catalogue.md`,
      `docs/11-api/rate-limiting.md` (status note only, no design change),
      `docs/12-security/identity-and-sessions.md`, `docs/12-security/tenant-isolation.md`,
      `docs/12-security/owasp-checklist.md`, `docs/modules/trading-day/specification.md` (status
      note only) all updated in the same PR.
- [x] backlog.md, implementation-log, `docs/README.md` updated in the same PR.

## Demo script

**Local, run 2026-08-20 (against a throwaway `postgres:15` container, port 15432 — the shared
5432 was already in use by an unrelated running project on this machine):**

1. `prisma migrate deploy` — applies cleanly, no pending migrations after the initial `migrate dev`
   run that generated `20260819203250_add_devices`. ✅
2. `node integration-tests/setup/apply-sql.mjs` — all 19 pre-existing RLS files plus the new
   `019_rls_devices.sql` apply without error. ✅
3. `vitest run --config vitest.integration.config.ts` — 98/98 (94 pre-existing + 4 new). ✅
4. `alter table devices disable row level security` (manual, via `psql`) — re-running the suite:
   exactly 3 failures, all `devices` cross-tenant cases (read/update/delete). ✅ (proves the test
   actually catches a broken policy, not just that it passes when the policy is correct)
5. `alter table devices enable row level security` — suite passes 98/98 again. ✅
6. `tsc --noEmit` — clean. `eslint` on every new/changed file — clean. `vitest run` (unit) —
   227/227. ✅

**Not performed this sprint, named rather than silently skipped:** a real live-HTTP smoke test of
the three new endpoints through an actual running Next.js server against the real Supabase project
this repository's `.env.local` points to. The mechanical Route Handler plumbing (Zod parsing,
`requireAuthenticatedUser`/`requirePermission`, `errorResponse`) is identical in shape to a dozen
already-live-verified endpoints in this codebase, and the security-critical part (RLS) was verified
directly against a real, authenticated Postgres connection with the deliberate-break-and-fix cycle
above — but the specific combination of a real Supabase-issued JWT plus this sprint's new
`X-Device-Id` header round-tripping through a live server was judged a more consequential use of a
real, shared external project than this sprint's verification needed, given the strength of the
coverage already in hand. A real device-registration flow exercised from an actual mobile build,
once Sprint 56 lands, will be the more meaningful live check regardless.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process
change — not pre-judged here. Worth naming regardless: this sprint is the first in this entire run
(48 through 55) to surface a genuine **rollout** risk rather than a **correctness** one — every
prior finding was "the code doesn't do what the doc says," fixable and verifiable entirely within
this session. This one required an actual judgment call only the founder could make (is anything
live right now that a hard new requirement would lock out), found by thinking through the
consequences of the change before merging it, not after.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-20 | Sprint 55: device registration/revocation built server-side — `devices` table (server-generated id, parent-join RLS via `users`), `POST /auth/register-device`/`GET /devices`/`PATCH /devices/{id}/revoke`, `requireSession`'s per-request `devices.revoked_at` check via a new `X-Device-Id` header. Closes Sprint 43's OWASP finding for `authorisation-model.md §2`'s device-revocation step. Verified against a real Postgres connection with the RLS deliberate-break-and-fix cycle (98/98 integration checks) and 9 new unit tests. Mobile wiring (register-device call, header, revoked-handling) deliberately deferred to a follow-up sprint — confirmed with the founder that no live reliance on the current backend makes this safe. |
