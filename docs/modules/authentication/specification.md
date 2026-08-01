# Module Specification — Authentication

> **Status:** 🟢 Approved (written retroactively — see §0; build status is tracked separately in [modules/README.md](../README.md), not conflated with this document's own review state)
> **Module:** Authentication
> **Slice:** V1
> **Version:** 0.1.0
> **Last updated:** 2026-08-01
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
creating a tenant) or role/permission enforcement (Roles & Permissions, not yet built).

## 2. Business rules

- A user belongs to exactly one tenant in V1 — no cross-tenant staff sharing
  ([schema-server.md](../../07-database/schema-server.md), Context 1, `users`).
- Every JWT Supabase issues for an authenticated `users` row carries a `tenant_id` claim, injected
  by the Custom Access Token Hook at mint and refresh time — never accepted as a client-supplied
  value ([tenancy-model.md §1](../../07-database/tenancy-model.md#1-how-a-request-knows-which-tenant-it-is)).
- A revoked device is rejected on its next API request regardless of remaining access-token
  validity ([authentication.md §4](../../11-api/authentication.md#4-device-binding-and-revocation--checked-on-every-request-not-only-at-token-mint)) —
  **not yet enforced in code** (see §10).
- Revocation does not retroactively invalidate an already-open Realtime subscription; the short
  (60-minute target) access-token lifetime is the accepted bound on that exposure window
  ([authentication.md §4](../../11-api/authentication.md#4-device-binding-and-revocation--checked-on-every-request-not-only-at-token-mint)).

## 3. Database tables and relationships

`users` and `devices`, per [schema-server.md](../../07-database/schema-server.md) Context 1 — full
column definitions there, not repeated here. **Built and live:** `users` (migration
`20260801050159_init`, RLS via `supabase/sql/002_rls_tenants_users.sql`). **Not yet built:**
`devices` — no migration exists for it yet; device registration/revocation (§4 below) is therefore
specified but not implemented.

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/auth/register-device` | **Not implemented.** Contract fixed in [authentication.md §2](../../11-api/authentication.md#2-issuance-flow) and [identity.md](../../11-api/endpoints/identity.md#devices). |
| `GET /devices` | **Not implemented.** Owner-only device list, per [identity.md](../../11-api/endpoints/identity.md#devices). |
| `PATCH /devices/{id}/revoke` | **Not implemented.** Per [authentication.md §5](../../11-api/authentication.md#5-revocation-flow). |

Sign-in itself is not a REST endpoint this API owns — it's a direct call from the client to
Supabase Auth ([authentication.md §1](../../11-api/authentication.md#1-why-supabase-auth-issues-the-token-not-a-second-one-from-our-api)),
which is why it has no row in the table above.

## 5. Validation rules (client and server)

Not yet applicable — no endpoint in §4 is implemented. When `register-device` is built,
`client_device_id` is required, server-generated (never client-chosen) is explicitly *not* the
rule — [identifiers.md §4](../../07-database/identifiers.md#4-edge-case--device-reinstallation-must-not-reuse-a-provisional-number-namespace)
fixes it as client-generated, fresh per install.

## 6. Error handling and user-facing messages

`DEVICE_REVOKED` (401) and `UNAUTHENTICATED`/`TOKEN_EXPIRED` (401) are defined in
[error-catalogue.md](../../11-api/error-catalogue.md) and already enforced for the "no session"
and "malformed/absent `tenant_id` claim" cases by `src/core/auth/session.ts`
(evaluation-order steps 1 and 3 of [authorisation-model.md §2](../../12-security/authorisation-model.md#2-evaluation-order--every-request-in-this-sequence-fail-closed-at-every-step)).
`DEVICE_REVOKED` itself (step 2) is not yet enforced — see §10.

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
[permission-matrix.md](../../05-personas/permission-matrix.md). No Flutter screen exists yet for
either — mobile app scaffolding has not started (`apps/mobile` has no Dart code, per
[implementation-log.md](../../18-implementation/implementation-log.md)); these routes and their
screens are built when the mobile client work reaches this module, not blocked on this
specification.

## 10. Test plan

**Run so far, against real infrastructure** (not a plan, a record —
[implementation-log.md](../../18-implementation/implementation-log.md)'s 2026-08-01 entries):
- Sign-in issues a JWT whose `tenant_id` claim matches the signed-in user's tenant — verified live.
- A cross-tenant read of another tenant's `tenants` row is denied by RLS — verified live (this
  exercises `users`' RLS policy indirectly, since the test session is itself a `users` row).
- Two real gaps found and fixed by this testing: the hook needed `security definer`; the circular
  FK needed `NO ACTION` instead of `RESTRICT` to actually defer.

**Not yet run, because the code doesn't exist yet:**
- Device registration, revocation, and the `DEVICE_REVOKED` rejection path (steps 4 above).
- Automated (CI) version of the cross-tenant proof above — currently a one-off manual script, per
  [tenancy-model.md §5](../../07-database/tenancy-model.md#5-the-proof-automated-cross-tenant-negative-test-suite)'s
  standing gap, tracked to Phase 14/18 as already noted project-wide.

## 11. Traceability

| Requirement | Covered by |
| --- | --- |
| [BR-005](../../02-business-requirements/business-requirements.md) (remote device revocation) | §3–§4 (not yet implemented) |
| [FR-001](../../03-functional-requirements/functional-requirements.md) (account creation budget/connectivity) | §7 |
| [FR-014](../../03-functional-requirements/functional-requirements.md) (device revocation) | §4 (not yet implemented) |
| [DR-017](../../03-functional-requirements/business-rules.md)/[DR-018](../../03-functional-requirements/business-rules.md) (server-side permission evaluation) | §6, `authorisation-model.md` §2 steps 1 & 3 (steps 2 & 4 pending) |

## What's honestly not done

Device registration and revocation (§4–§6, §10) — no `devices` migration, no route handlers.
Evaluation-order steps 2 (device revocation) and 4 (role resolution) are not implemented in
`src/core/auth/session.ts`, matching what Sprint 01 already stated explicitly. This module is
**not** ✅ Done by [definition-of-done.md](../../00-governance/definition-of-done.md)'s own
standard — it is 🔨 In implementation, honestly partial, tracked to a future sprint for the
`devices` slice rather than claimed complete.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-01 | First version, written retroactively to catch this specification up to Sprint 01's already-live code (§0). Sign-in/hook/session-resolution documented as built; device registration/revocation documented as specified but not implemented. |
