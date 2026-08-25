# Module Specification — Authentication

> **Status:** 🟢 Approved (written retroactively — see §0; build status is tracked separately in [modules/README.md](../README.md), not conflated with this document's own review state)
> **Module:** Authentication
> **Slice:** V1
> **Version:** 0.3.0
> **Last updated:** 2026-08-26
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).

---

## 0. Why this specification is dated after some of its own code

[docs/README.md](../../README.md)'s non-negotiable rule #1 is "design before code," and this
Module Registry's own rule 1 is "a module enters 🔨 only when its specification is 🟢." Sprint 01
([sprint-01.md](../../17-sprints/sprint-01.md)) built real Authentication-module infrastructure —
the `users` table, the Custom Access Token Hook, RLS on `users`, and partial session resolution —
without this specification existing first. That is a genuine process gap, named here rather than
quietly retrofitted: this document was written to catch up to code that already runs against a
live database, not the reverse. It is treated with the same rigor as if it had come first — every
section below is checked against what actually exists, not what would be convenient to claim.
Everything *not yet* built is marked so explicitly in §10 rather than implied as done.

## 1. Purpose and business context

Establishes who a request is from and which tenant they belong to — the foundation every other
module's authorisation depends on ([authorisation-model.md](../../12-security/authorisation-model.md)).
Owns two things: the sign-in/token lifecycle (Supabase Auth, used as-is per
[authentication.md §1](../../11-api/authentication.md#1-why-supabase-auth-issues-the-token-not-a-second-one-from-our-api))
and per-device session tracking for remote revocation
([BR-005](../../02-business-requirements/business-requirements.md)). It does **not** own account
*creation* (that's [Company & Store Setup](../company-store-setup/specification.md)'s
`POST /api/v1/onboarding`, which happens to also write the first `users` row as a side effect of
creating a tenant) or role/permission enforcement ([Roles & Permissions](../roles-permissions/specification.md) — built Sprint 23, a separate module this one does not own).

## 2. Business rules

- A user belongs to exactly one tenant in V1 — no cross-tenant staff sharing
  ([schema-server.md](../../07-database/schema-server.md), Context 1, `users`).
- Every JWT Supabase issues for an authenticated `users` row carries a `tenant_id` claim, injected
  by the Custom Access Token Hook at mint and refresh time — never accepted as a client-supplied
  value ([tenancy-model.md §1](../../07-database/tenancy-model.md#1-how-a-request-knows-which-tenant-it-is)).
- A revoked device is rejected on its next API request regardless of remaining access-token
  validity ([authentication.md §4](../../11-api/authentication.md#4-device-binding-and-revocation--checked-on-every-request-not-only-at-token-mint)) —
  **built and enforced, Sprint 55**: `core/auth/session.ts#requireSession`'s own evaluation-order
  step 2 calls `devicesService.assertDeviceUsable`, checked against the `X-Device-Id` header on
  every request (see §10 for a correction to this document's own long-stale "not yet run" claim).
- Revocation does not retroactively invalidate an already-open Realtime subscription; the short
  (60-minute target) access-token lifetime is the accepted bound on that exposure window
  ([authentication.md §4](../../11-api/authentication.md#4-device-binding-and-revocation--checked-on-every-request-not-only-at-token-mint)).

## 3. Database tables and relationships

`users` and `devices`, per [schema-server.md](../../07-database/schema-server.md) Context 1 — full
column definitions there, not repeated here. **Built and live:** `users` (migration
`20260801050159_init`, RLS via `supabase/sql/002_rls_tenants_users.sql`). **Built and live, Sprint
55:** `devices` (migration `20260819203250_add_devices`) — device registration/revocation (§4
below) is fully implemented, not merely specified. This paragraph said `devices` had "no migration"
for 17 sprints after Sprint 55 actually built it; the whole document was never revisited after
Sprint 06 until this correction, despite §0's own stated rigor that "every section below is checked
against what actually exists" — corrected here, dated, rather than left to mislead a future reader.

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/auth/register-device` | **Built, Sprint 55.** Any authenticated user registers their own device (`requireAuthenticatedUser`, not role-gated — matches the natural "I am signing in on this device" action). Contract per [authentication.md §2](../../11-api/authentication.md#2-issuance-flow) and [identity.md](../../11-api/endpoints/identity.md#devices). |
| `GET /devices` | **Built, Sprint 55.** Owner-only (`requirePermission(["owner"])`), per [identity.md](../../11-api/endpoints/identity.md#devices). |
| `PATCH /devices/{id}/revoke` | **Built, Sprint 55.** Owner-only (`requirePermission(["owner"])`). Per [authentication.md §5](../../11-api/authentication.md#5-revocation-flow). |

Sign-in itself is not a REST endpoint this API owns — it's a direct call from the client to
Supabase Auth ([authentication.md §1](../../11-api/authentication.md#1-why-supabase-auth-issues-the-token-not-a-second-one-from-our-api)),
which is why it has no row in the table above.

## 5. Validation rules (client and server)

**Built, Sprint 55.** `client_device_id` is required and client-generated (never server-assigned) —
[identifiers.md §4](../../07-database/identifiers.md#4-edge-case--device-reinstallation-must-not-reuse-a-provisional-number-namespace)'s
fixed rule — while the `devices.id` row itself is the one deliberate, documented exception to this
schema's usual client-generated-id convention (server-generated via `randomUUID()` at
register-device time, since no offline client ever writes this row directly — see
[schema-server.md](../../07-database/schema-server.md)'s own `devices` entry). Mobile generates and
persists `client_device_id` once per install, registering on sign-in and again on every launch
(best-effort).

## 6. Error handling and user-facing messages

`DEVICE_REVOKED` (401) and `UNAUTHENTICATED`/`TOKEN_EXPIRED` (401) are defined in
[error-catalogue.md](../../11-api/error-catalogue.md) and enforced by `src/core/auth/session.ts`'s
`requireSession` across all four of its evaluation-order steps
([authorisation-model.md §2](../../12-security/authorisation-model.md#2-evaluation-order--every-request-in-this-sequence-fail-closed-at-every-step)):
(1) JWT verification, (2) `DEVICE_REVOKED` — built Sprint 55, `devicesService.assertDeviceUsable`
against the `X-Device-Id` header, (3) `tenant_id` claim resolution, (4) current-role resolution via
`user_store_roles` (Roles & Permissions, Sprint 23). On mobile, a `DEVICE_REVOKED` response forces
an immediate local sign-out (Sprint 56).

## 7. Offline behaviour

Sign-in requires connectivity by nature — a credential check against a server that has never been
reached cannot succeed ([FR-001](../../03-functional-requirements/functional-requirements.md)).
Device registration likewise requires connectivity
([authentication.md §2](../../11-api/authentication.md#2-issuance-flow)). Nothing in this module
queues for later sync; this is the one part of the onboarding journey
([WF-001](../../06-workflows/sales-workflows.md#wf-001--shop-onboarding)) that cannot be offline.

## 8. Realtime behaviour

No Realtime channel is owned by this module. The one Realtime-adjacent fact: a revoked device's
existing Realtime subscription is **not** actively torn down — it remains technically valid until
its access token naturally expires, a known and accepted gap bounded by the short token TTL
([authentication.md §4](../../11-api/authentication.md#4-device-binding-and-revocation--checked-on-every-request-not-only-at-token-mint)).

## 9. UI specification

`/auth/login` and `/auth/verify`, per [route-map.md](../../09-navigation/route-map.md) — no guard
(unauthenticated-only routes), the `/auth/login` route explicitly requiring connectivity per the
same table. Device-list/revocation UI is Owner-only, per
[permission-matrix.md](../../05-personas/permission-matrix.md).

**`/auth/login` is built** (Sprint 06, `apps/mobile/lib/features/authentication/`) — the first real
Flutter screen in the project. It calls Supabase Auth directly (§4), persists the session via
`flutter_secure_storage`, and `app/router.dart`'s redirect guard sends every unauthenticated route
to it. **`/auth/verify` is not built** — new-account email confirmation is driven by Company &
Store Setup's web onboarding flow, not mobile, per §1's scope boundary; nothing in M0's backlog
currently needs it on-device. **Correction:** the backend (§4) is fully built, Sprint 55 — only the
Owner-facing device-list/revocation *screen* remains genuinely unbuilt (confirmed by grep: no
device-list route or widget exists anywhere in `apps/mobile/lib`). What Sprint 55/56 did build on
the client side is narrower than a management screen: `client_device_id` generation/registration
(§5) and the `DEVICE_REVOKED` → forced-sign-out reaction (§6) — both are Sprint 56 mobile work, not
this still-open UI gap.

## 10. Test plan

**Run so far, against real infrastructure** (not a plan, a record —
[implementation-log.md](../../18-implementation/implementation-log.md)'s 2026-08-01 entries):
- Sign-in issues a JWT whose `tenant_id` claim matches the signed-in user's tenant — verified live.
- A cross-tenant read of another tenant's `tenants` row is denied by RLS — verified live (this
  exercises `users`' RLS policy indirectly, since the test session is itself a `users` row).
- Two real gaps found and fixed by this testing: the hook needed `security definer`; the circular
  FK needed `NO ACTION` instead of `RESTRICT` to actually defer.
- Mobile: `SupabaseAuthRepository.signInWithPassword` verified live against real Supabase Auth
  (Sprint 06) — success (session created, correct user), sign-out (session cleared), and a wrong
  password (rejected, mapped to `AuthFailure`). Widget tests cover the login screen's
  loading/validation/error states against a fake repository
  (`test/features/authentication/presentation/screens/login_screen_test.dart`).

**Correction — the item below was run long ago and this section was simply never updated:**
- Device registration, revocation, and the `DEVICE_REVOKED` rejection path — run Sprint 55 (server:
  98/98 integration checks against a real Postgres connection, the same deliberate-break-and-fix
  rigor Sprint 40 established) and Sprint 56 (mobile: `flutter test` 273/273).

**Still genuinely not run:**
- Automated (CI) version of the cross-tenant proof above — this specific gap remains real; `fast-
  integration` (Sprint 40) since automated the *general* cross-tenant RLS suite across 20 tables
  including `devices` itself, but the exact one-off manual script described here for `users`/`tenants`
  specifically was never individually ported — a narrower residual gap than this section originally
  implied, not a wholesale missing capability.

## 11. Traceability

| Requirement | Covered by |
| --- | --- |
| [BR-005](../../02-business-requirements/business-requirements.md) (remote device revocation) | §3–§4 (built, Sprint 55) |
| [FR-001](../../03-functional-requirements/functional-requirements.md) (account creation budget/connectivity) | §7 |
| [FR-014](../../03-functional-requirements/functional-requirements.md) (device revocation) | §4 (built, Sprint 55) |
| [DR-017](../../03-functional-requirements/business-rules.md)/[DR-018](../../03-functional-requirements/business-rules.md) (server-side permission evaluation) | §6, `authorisation-model.md` §2, all four evaluation-order steps built |

## What's honestly not done

**Correction (2026-08-26):** this section described Sprint 01-era reality (2026-08-01) and was never
updated across the 55+ sprints since, despite this exact document's own §0 promising the opposite
discipline. The backend this section called undone — `devices`, all three device endpoints, both
evaluation-order steps — has been built, live-verified, and in production use since Sprint 55
(2026-08-20). What remains genuinely unbuilt, narrower than this section previously implied: the
Owner-facing device-list/revocation **UI screen** on mobile (§9) — the backend and the client-side
registration/revocation-reaction logic (§5–§6) exist; a screen to browse and act on the device list
does not. This module is still **not** ✅ Done by
[definition-of-done.md](../../00-governance/definition-of-done.md)'s own standard for that one
reason, not for the reasons this section originally gave.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-01 | First version, written retroactively to catch this specification up to Sprint 01's already-live code (§0). Sign-in/hook/session-resolution documented as built; device registration/revocation documented as specified but not implemented. |
| 0.2.0 | 2026-08-02 | Sprint 06: `/auth/login` documented as built — the mobile client's first real screen, verified live against Supabase Auth. `/auth/verify` and device registration/revocation remain undone. |
| 0.3.0 | 2026-08-26 | Sprint 74 (module-registry staleness audit): this document was never updated for 55+ sprints after Sprint 06, despite Sprint 23 (Roles & Permissions), Sprint 55 (device registration/revocation, server), and Sprint 56 (device registration/revocation, mobile) each building exactly what §§1–11 kept describing as unbuilt — an ironic, significant gap given §0's own explicit promise that "every section... is checked against what actually exists." Corrected: §1 (Roles & Permissions is built), §2/§6 (`DEVICE_REVOKED` enforcement, all four `requireSession` evaluation-order steps), §3 (`devices` table live), §4 (all three device endpoints built, with their actual permission gating), §5 (validation rules as actually implemented), §9 (narrowed to the one genuinely remaining gap — the device-list/revocation UI screen, confirmed unbuilt by direct grep, distinct from the now-built backend), §10 (the device test-plan items were run, Sprint 55/56 — narrowed the one still-real automation gap), §11, and "What's honestly not done" (rewritten to name the actual remaining gap, not the 2026-08-02 one). Every correction verified against real code (`session.ts`, the three `devices`/`register-device` route files, a grep for any mobile device-list screen) before being written, not assumed from sprint summaries alone. |
