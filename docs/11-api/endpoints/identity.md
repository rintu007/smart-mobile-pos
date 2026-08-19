# Endpoints — Identity & Tenancy

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.4.0
> **Last updated:** 2026-08-20
> **Owner:** Principal Next.js Engineer
> **Approved by:** _pending_

Covers `stores`, `users`, `user_store_roles`, `devices`, `audit_log`
([schema-server.md](../../07-database/schema-server.md)'s Context 1). Conventions
([error envelope](../error-catalogue.md), [pagination](../api-principles.md#4-pagination--cursor-only),
[idempotency](../api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation))
apply as stated in [api-principles.md](../api-principles.md); not repeated per row below.

---

## Onboarding

**This section closes a real gap found at Phase 18 implementation time**: [authentication.md](../authentication.md)'s
issuance flow starts from "App→Auth: Sign in," implicitly assuming a `tenants`/`stores`/`users` row
already exists — but nothing in Phase 11 originally specified how the *first* tenant, store, and
user actually get created. [WF-001](../../06-workflows/sales-workflows.md#wf-001--shop-onboarding)
already covers this at the workflow level ("Create account & verify," step 2) and
[FR-001](../../03-functional-requirements/functional-requirements.md) fixes its budget and
connectivity requirement; this is that step's concrete API contract.

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `POST /api/v1/onboarding` | Any authenticated Supabase Auth identity with **no existing `public.users` row** | No — [FR-001](../../03-functional-requirements/functional-requirements.md) requires connectivity for this one step | Creation mechanism (client-generated `tenant_id`/`store_id`/`user_id`) | Creates exactly one `tenants` row, one `stores` row, and one `users` row, atomically, per [ADR-0003](../../adr/ADR-0003-multi-outlet-modelled-from-day-one.md)'s "create tenant → create default store → attach user" sequence. |

**Sequence:**
1. The client has already completed a normal Supabase Auth `signUp` (email/password or OTP,
   [authentication.md §1](../authentication.md#1-why-supabase-auth-issues-the-token-not-a-second-one-from-our-api))
   and holds a valid access token. That token's `tenant_id` claim is absent at this point — the
   Custom Access Token Hook found nothing in `public.users` for this `auth_user_id` yet, which is
   expected and not an error.
2. The client calls `POST /api/v1/onboarding` with the new access token, a client-generated
   `tenant_id`, `store_id`, and `user_id` (all UUIDv4, per [ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md)),
   plus `tenant_name`, `store_name`, `store_address` (optional), and `display_name`.
3. The server verifies no `public.users` row exists for this `auth_user_id` yet, then inserts all
   three rows in one transaction — `tenants.created_by` and `users.tenant_id` are the same
   circular-bootstrapping pair documented in
   [implementation-log.md](../../18-implementation/implementation-log.md)'s 2026-08-01 entries,
   resolved the same way (`DEFERRABLE INITIALLY DEFERRED`, `ON DELETE NO ACTION`).
4. The response body returns the three created rows. **The access token the client is still holding
   does not yet carry the `tenant_id` claim** — the hook only runs at mint/refresh, and minting
   happened in step 1, before these rows existed. The client must refresh its session
   (`supabase.auth.refreshSession()` or equivalent) immediately after a successful response to
   obtain a token that actually carries `tenant_id`; every subsequent tenant-scoped request depends
   on this refresh having happened.
5. **Sprint 23 update: a `user_store_roles` row is now created here too**, in the same
   transaction — `role: 'owner'`, reusing `user_id` as this row's own id (a natural 1:1, per
   [roles-permissions/specification.md §3](../../modules/roles-permissions/specification.md#3-database-tables-and-relationships)).
   Before Sprint 23, this section correctly noted that no such row was created, since Roles &
   Permissions didn't exist yet; that gap is now closed — the onboarding user is formally the
   Owner the moment onboarding completes, and every permission check added since Sprint 23
   recognises them as such immediately.
6. **Sprint 25 update: a `shop_settings` row is now created here too**, in the same transaction —
   [settings/specification.md §2](../../modules/settings/specification.md#2-business-rules)'s
   universal defaults, `tenant_id` reused as this row's own id (that table's own primary key).
   **The response body itself is unchanged** — still the tenant/store/user/role rows named in step
   4 above, not five. `shop_settings` carries two `BIGINT` columns, which broke
   `NextResponse.json`'s serialization the first time this was tried (found live, not by
   inspection): the fix was to keep this endpoint's response shape exactly as it already was, not
   to add `BigInt`-to-`Number` formatting for a field nothing in this contract has ever returned.

**Retry behaviour:** a retry with the *same* `tenant_id`/`store_id`/`user_id` (e.g. a client that
never received the first response) is a normal idempotent replay — `INSERT ... ON CONFLICT (id) DO
NOTHING`, per [api-principles.md §3](../api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation).
A *second, distinct* onboarding attempt from an identity that already has a `public.users` row
(different generated IDs, same `auth_user_id`) is a different logical operation, not a retry of the
first — rejected outright with `ALREADY_ONBOARDED`, per `users.auth_user_id`'s own `UNIQUE`
constraint, rather than silently merged or treated as equivalent to the first call.

## Errors specific to onboarding

| Code | HTTP | Cause |
| --- | --- | --- |
| `ALREADY_ONBOARDED` | 409 | This `auth_user_id` already has a `public.users` row — see Retry behaviour above. |

---

## Stores

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `GET /stores` | Any authenticated role | Read cached, no queued write | N/A (read) | V1 always returns exactly one store per tenant — [ADR-0003](../../adr/ADR-0003-multi-outlet-modelled-from-day-one.md). No selector shown; the client uses the single result. |
| `PATCH /stores/{id}` | Owner | No — requires connectivity | State-transition mechanism (`client_operation_id`) | Name/address edits only; infrequent, back-office. |

## Users & roles

**Implementation note (Sprint 23, [roles-permissions/specification.md](../../modules/roles-permissions/specification.md)):**
all four rows below are built and live-verified. **`POST /users/invite`'s mechanism is corrected
from this section's original wording** — there is no separate "pending record" state at all.
Supabase Admin's `inviteUserByEmail` creates the (unconfirmed) Auth identity **synchronously** and
returns its real `auth_user_id` immediately; the `users` row is created against that id in the same
call. "The invitee completes signup" now just means they set a password and start using an
identity that already fully exists in this system — not a later linking step.

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `GET /users` | Manager, Owner | Read cached | N/A | Returns each user's current role per [user_store_roles](../../07-database/schema-server.md), filtered to non-revoked assignments and joined against `deactivated_at`. |
| `POST /users/invite` | Owner | No | Creation mechanism (client `id`) | Creates the Auth identity via `admin.inviteUserByEmail`, then the `users` row and its initial `user_store_roles` row, transactionally, against that identity's real `auth_user_id` — see the implementation note above. |
| `PATCH /users/{id}/role` | Owner | No | State-transition | Writes a **new** `user_store_roles` row and sets `revoked_at` on the prior one — roles are versioned, never updated in place, per [DR-019](../../03-functional-requirements/business-rules.md)–[DR-021](../../03-functional-requirements/business-rules.md), preserving who-could-do-what-when for audit. |
| `DELETE /users/{id}` | Owner | No | State-transition | Sets `deactivated_at` (Tier 1 soft delete) — never a hard delete, per [ADR-0009](../../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md). Role resolution excludes a deactivated user's assignments by construction; no separate role-revocation write is needed or performed. |

## Devices

**Built, Sprint 55** — Sprint 43's OWASP checklist review flagged this whole section as a real,
unaddressed gap (`authorisation-model.md §2`'s step 2 had no `devices` table to check against).
Built exactly as already designed here, plus one previously-unspecified detail resolved while
implementing: `client_device_id` is presented on every request via a new `X-Device-Id` header
(`authentication.md §4`'s own dated correction).

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `POST /auth/register-device` | Any authenticated user (self only) | No — this is the connectivity-establishing call itself | Creation mechanism (`client_device_id` is itself the natural dedup key — a second call with the same `client_device_id` updates `last_seen_at` rather than creating a duplicate row) | See [authentication.md §2](../authentication.md#2-issuance-flow). |
| `GET /devices` | Owner | Read cached | N/A | Device-revocation UI list, per [permission-matrix.md](../../05-personas/permission-matrix.md). |
| `PATCH /devices/{id}/revoke` | Owner | No | State-transition | See [authentication.md §5](../authentication.md#5-revocation-flow). Irreversible via this endpoint — a revoked device re-registers as a new device (§4 of [identifiers.md](../../07-database/identifiers.md)), never un-revokes. |

## Audit log

**Built this sprint** (Sprint 23) — see [audit-log/specification.md](../../modules/audit-log/specification.md).
**Correction to this table's own Permission cell**: it read "Owner" only, inconsistent with
[permission-matrix.md](../../05-personas/permission-matrix.md)/[audit-model.md §3](../../07-database/audit-model.md#3-who-can-read-it)'s
already-established "Owner **and Manager**, not Cashier" — a stale Phase-11 cell, not a newer,
more-restrictive decision; corrected to match the two documents that actually derived this rule,
implemented and live-verified as Manager+Owner.

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `GET /audit-log` | Manager, Owner | Read cached (list is typically viewed back-office, online) | N/A | Cursor-paginated on `(created_at, id)`. Filters: `entity_type`, `entity_id`, `date_from`, `date_to`. This table is **never written to directly by any client-facing endpoint** — every mutating endpoint across every module writes its own audit row server-side as part of the same transaction as the business mutation, per [BR-009](../../02-business-requirements/business-requirements.md). There is no `POST /audit-log`. |

## Errors specific to this module

| Code | HTTP | Cause |
| --- | --- | --- |
| `DEVICE_REVOKED` | 401 | See [authentication.md §4](../authentication.md#4-device-binding-and-revocation--checked-on-every-request-not-only-at-token-mint). |
| `LAST_OWNER_CANNOT_BE_REMOVED` | 409 | `PATCH /users/{id}/role` or `DELETE /users/{id}` would leave the tenant with zero active Owners — rejected outright, since that is an unrecoverable lockout, not a business choice to allow. |
| `EMAIL_ALREADY_REGISTERED` | 409 | **New (Sprint 23).** `POST /users/invite`'s `email` already has a Supabase Auth identity — Supabase Admin's own duplicate-email rejection, translated to a named code. |
| `ALREADY_ONBOARDED` | 409 | See the Onboarding section above. |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial identity/device/audit endpoint set. |
| 0.2.0 | 2026-08-01 | Added the Onboarding section (`POST /api/v1/onboarding`) — a genuine gap found at Phase 18 implementation time: nothing in this phase previously specified how the very first tenant/store/user rows are created, only the sign-in flow for an identity that already has them. |
| 0.3.0 | 2026-08-14 | Sprint 23: `GET/POST/PATCH/DELETE /users*` and `GET /audit-log` all built and live-verified. Onboarding now also creates the initial `owner` role row. `POST /users/invite`'s mechanism corrected — no separate "pending record" state, Supabase Admin's `inviteUserByEmail` creates the real identity synchronously. Audit log's Permission cell corrected from "Owner" to "Manager, Owner" (a stale Phase-11 cell, inconsistent with permission-matrix.md/audit-model.md's own already-established rule). Added `EMAIL_ALREADY_REGISTERED`. |
| 0.3.1 | 2026-08-14 | Sprint 25: onboarding now also creates a default `shop_settings` row (backlog.md M2 item 1). Response shape confirmed unchanged — a real BigInt-serialization bug found live during this sprint's own implementation was fixed by keeping the existing response shape, not by adding the new row to it. |
| 0.4.0 | 2026-08-20 | Sprint 55: `POST /auth/register-device`, `GET /devices`, `PATCH /devices/{id}/revoke` built and verified against a real Postgres connection (RLS deliberate-break-and-fix cycle, 98/98 integration checks). Closes Sprint 43's OWASP finding for `authorisation-model.md §2`'s device-revocation step. |
