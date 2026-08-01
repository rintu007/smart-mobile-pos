# Module Specification — Company & Store Setup

> **Status:** 🟢 Approved
> **Module:** Company & Store Setup
> **Slice:** V1
> **Version:** 0.1.0
> **Last updated:** 2026-08-01
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 02](../../17-sprints/sprint-02.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

Creates the `tenants` and `stores` rows that everything else in the product is scoped to. V1's
scope is deliberately narrow: **one tenant, one store, created once, at signup, never edited into
a second store** ([ADR-0003](../../adr/ADR-0003-multi-outlet-modelled-from-day-one.md)). This
module owns exactly the server-side half of
[WF-001](../../06-workflows/sales-workflows.md#wf-001--shop-onboarding)'s "Create account &
verify" step; the client-local steps that follow it (business type defaults, shop identity
capture, first products, first sale) belong to other modules (Settings, Products, POS
respectively) and are explicitly out of scope here.

## 2. Business rules

- Exactly one `stores` row is created per tenant, automatically, at onboarding — never a store
  picker, never a second store creatable in V1
  ([ADR-0003](../../adr/ADR-0003-multi-outlet-modelled-from-day-one.md)).
- A tenant cannot be created without simultaneously creating its first store and its first user —
  there is no intermediate state where a `tenants` row exists with no store or no user.
- The signing-up identity does **not** receive a formal Owner role as part of this module — that's
  `user_store_roles`, owned by the not-yet-built Roles & Permissions module. This is a named scope
  boundary (see [identity.md's Onboarding section, step 5](../../11-api/endpoints/identity.md#onboarding)),
  not an oversight.
- `stores.name`/`stores.address` and `tenants.name` are free text, no uniqueness constraint across
  tenants (two different shops can share a name) — only `users.auth_user_id` is globally unique.

## 3. Database tables and relationships

`tenants` and `stores`, per [schema-server.md](../../07-database/schema-server.md) Context 1 — full
column definitions there. **Built and live** (migration `20260801050159_init`): both tables, RLS on
`tenants` (`supabase/sql/002_rls_tenants_users.sql`). **Not yet built:** RLS on `stores` — Sprint 01
only enabled RLS on `tenants`/`users` since those were the two tables the Custom Access Token Hook
demo needed; `stores` RLS is in this module's own scope (§10) since this module is what actually
writes to `stores`.

The circular bootstrapping pair (`tenants.created_by → users.id`, `users.tenant_id → tenants.id`)
is resolved with `DEFERRABLE INITIALLY DEFERRED` / `ON DELETE NO ACTION`, already live — see
[implementation-log.md](../../18-implementation/implementation-log.md)'s 2026-08-01 entries. This
module's own migration work is additive (RLS on `stores`), not a repeat of that fix.

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/onboarding` | **To be implemented this sprint.** Full contract in [identity.md's Onboarding section](../../11-api/endpoints/identity.md#onboarding) — not repeated here to avoid two sources of truth for the same contract; this module is one of its two owners (alongside `users`, which [Authentication](../authentication/specification.md) owns). |
| `GET /stores` | **Already documented**, not yet implemented — [identity.md](../../11-api/endpoints/identity.md#stores). Always returns exactly one row per tenant in V1. |
| `PATCH /stores/{id}` | **Already documented**, not yet implemented — [identity.md](../../11-api/endpoints/identity.md#stores). Deferred past this sprint (§10) — Sprint 02 is create-only, matching [backlog.md](../../17-sprints/backlog.md) item 3's "minimal write path" framing. |

## 5. Validation rules (client and server)

Request body for `POST /api/v1/onboarding` (Zod schema, server-side — client-side validation is UX
only, never trusted, per [definition-of-done.md](../../00-governance/definition-of-done.md)):

| Field | Rule |
| --- | --- |
| `tenant_id`, `store_id`, `user_id` | UUIDv4, required — client-generated per [ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md) |
| `tenant_name` | Non-empty string, required, max 200 chars |
| `store_name` | Non-empty string, required, max 200 chars |
| `store_address` | Optional string, max 500 chars — matches [FR-003](../../03-functional-requirements/functional-requirements.md)'s "no field required beyond name and currency" (currency itself is a Settings-module concern, not captured here) |
| `display_name` | Non-empty string, required, max 200 chars — the signing-up user's display name |

Server-side, in addition to schema validation: the caller's `auth_user_id` (from the verified JWT,
never from the request body) must not already have a `public.users` row — see `ALREADY_ONBOARDED`
in [identity.md](../../11-api/endpoints/identity.md#errors-specific-to-onboarding).

## 6. Error handling and user-facing messages

`VALIDATION_FAILED` (422) for schema failures, `ALREADY_ONBOARDED` (409) for the repeat-signup
case — both per [error-catalogue.md](../../11-api/error-catalogue.md). No new user-facing copy is
specified here; actual on-screen wording is [voice-and-tone.md](../../10-design-system/voice-and-tone.md)'s
concern at mobile-build time, not fixed prematurely by this backend-only sprint.

## 7. Offline behaviour

Not offline — `POST /api/v1/onboarding` requires connectivity, matching
[FR-001](../../03-functional-requirements/functional-requirements.md)'s explicit exception to an
otherwise-offline onboarding flow. `GET /stores` is read-cached once implemented (per
[identity.md](../../11-api/endpoints/identity.md#stores)), not relevant to Sprint 02's create-only
scope.

## 8. Realtime behaviour

None. Tenant/store creation happens exactly once per tenant and is never pushed to other clients —
there are no "other clients" yet at the moment this endpoint runs.

## 9. UI specification

`/onboarding/business-type`, `/onboarding/shop-identity` per
[route-map.md](../../09-navigation/route-map.md) — no guard (new-Owner-mid-signup), both fully
offline on the client side (only the final submission to `POST /api/v1/onboarding` needs
connectivity). No Flutter screen exists yet — same statement as
[Authentication's specification §9](../authentication/specification.md#9-ui-specification); not a
blocker for this backend-only sprint, since Sprint 02 (per its own capacity check) is Repository/API
work, not mobile UI.

## 10. Test plan

**Sprint 02 scope (to be run, not yet run — written before code per this document's own purpose):**
- Unit test: `POST /api/v1/onboarding` creates exactly one `tenants`, one `stores`, one `users` row
  in a single transaction.
- Unit test: a retry with identical `tenant_id`/`store_id`/`user_id` is a no-op (idempotent replay),
  per [api-principles.md §3](../../11-api/api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation).
- Unit test: a second attempt from an already-onboarded `auth_user_id` (fresh generated IDs) is
  rejected with `ALREADY_ONBOARDED`.
- Integration test: after a successful call, refreshing the session yields a JWT whose `tenant_id`
  claim matches the newly created tenant — extends Sprint 01's manual proof
  ([implementation-log.md](../../18-implementation/implementation-log.md)) into an actual endpoint,
  not a hand-run fixture script.
- Cross-tenant negative test: tenant A's authenticated session cannot read tenant B's `stores` row
  — requires RLS on `stores` (§3) to actually be enabled first.

**Explicitly deferred past Sprint 02:** `PATCH /stores/{id}`, `GET /stores`'s own test coverage
(endpoint exists in the contract but isn't part of this sprint's implementation — §4).

## 11. Traceability

| Requirement | Covered by |
| --- | --- |
| [FR-001](../../03-functional-requirements/functional-requirements.md) (account creation, 2-min budget, requires connectivity) | §7, §4 |
| [FR-003](../../03-functional-requirements/functional-requirements.md) (shop identity capture) | §5 (`tenant_name`/`store_name`/`store_address`) |
| [ADR-0003](../../adr/ADR-0003-multi-outlet-modelled-from-day-one.md) (one store per tenant, store-scoping modelled from day one) | §2, §3 |
| [BR-001](../../02-business-requirements/business-requirements.md) | §7 (onboarding time budget) |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-01 | First version — written to drive Sprint 02's implementation of `POST /api/v1/onboarding`. Scope deliberately narrow: tenant+store creation only, `PATCH /stores/{id}` explicitly deferred. |
