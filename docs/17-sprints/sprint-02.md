# Sprint 02

> **Dates:** Started 2026-08-01
> **Milestone:** M0 — Walking Skeleton
> **Status:** Planned

## Goal

A new business can sign up and get exactly one tenant and one store created server-side —
atomically, safely retryable, and provably isolated from every other tenant.

## Scope

Backlog item 3 from [backlog.md §1](backlog.md#1-m0--walking-skeleton-fully-decomposed) — one
module, [Company & Store Setup](../modules/company-store-setup/specification.md), well inside this
phase's ≤2-module limit. Item 4 (Local Drift DB scaffold) is next in dependency order but requires
the Flutter SDK, still not installed in this environment
([implementation-log.md](../18-implementation/implementation-log.md)) — not pulled into this sprint
just to fill capacity.

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `tenants`/`stores` minimal write path — a signup creates one tenant and one store | Company & Store Setup | 1.0 | 2 (done, Sprint 01) |

## Capacity check

1.0 person-day of scope against a ~3.75 person-day sprint budget (midpoint pace, per
[sprint-cadence.md §1](sprint-cadence.md#1-sprint-length--2-weeks)) — 2.75 person-days of headroom.
This is deliberately not padded with unrelated work to look fuller: no other backlog item is
actually unblocked (item 4 needs Flutter; items 5+ need item 4), and Sprint 01's own retrospective
([retrospective-log.md](retrospective-log.md)) is exactly the reminder not to manufacture scope for
its own sake. The headroom is allocated below instead — most of it to documentation, since writing
[the Authentication](../modules/authentication/specification.md) and
[Company & Store Setup](../modules/company-store-setup/specification.md) module specifications
(a real, found gap — see their own §0/changelog) and the missing `POST /api/v1/onboarding` contract
in [identity.md](../11-api/endpoints/identity.md) happened as part of *opening* this sprint, not
as a footnote after it.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-days — this is the first sprint writing to
      previously-untouched tables (`stores`) under RLS and the first real multi-row transactional
      endpoint; per Sprint 01's own retrospective finding, "verified locally" and "CI-ready" are
      different claims, so budget exists for whatever a real PR run surfaces.
- [x] Documentation capacity reserved: 1.0 person-day — covers the module-specification and
      API-contract gap-filling already done at sprint open (see Capacity check above), which is
      real Sprint 02 work, not free.

## Risks

- **Estimate risk:** backlog.md's original 1.0-person-day estimate for this item was made before
  [company-store-setup/specification.md](../modules/company-store-setup/specification.md) existed
  in this much detail (idempotency semantics, RLS-on-`stores`, the `ALREADY_ONBOARDED` retry
  distinction). If implementation reveals the estimate was optimistic, that consumes the 2.75-day
  headroom rather than blowing the sprint — but it's named here, not discovered silently.
- **[R-10](../01-vision/risks-constraints-assumptions.md) (dependency abandonment)** — carried
  forward from Sprint 01, still low likelihood, still worth a standing mention per that sprint's
  own risk register.
- The circular-FK deferred-constraint pattern ([implementation-log.md](../18-implementation/implementation-log.md))
  is being *reused*, not invented, in this sprint's transaction — low risk, but worth naming since
  it's exactly the kind of thing that looked simple the first time and deserves a second look under
  slightly different conditions (three rows this time, not two — `stores` has no circular
  dependency itself, but shares the transaction).

## Definition of Done

Unlike Sprint 01 (pure infrastructure, held to a narrow subset), this sprint builds a real
(if minimal) module slice, so more of [definition-of-done.md](../00-governance/definition-of-done.md)
actually applies — still not the full checklist, since mobile/offline/UI boxes don't apply to a
backend-only, connectivity-required endpoint with no Flutter client yet:

- [ ] Module specification exists, all 11 sections, 🟢 Approved —
      [company-store-setup/specification.md](../modules/company-store-setup/specification.md)
- [ ] Schema: RLS enabled on `stores` (currently only `tenants`/`users` have it — see the
      specification's §3), migration reviewed and applied to the live Supabase database
- [ ] `POST /api/v1/onboarding` matches [identity.md's Onboarding section](../11-api/endpoints/identity.md#onboarding)
      exactly; every input validated with Zod at the boundary
- [ ] Endpoint is idempotent per its documented retry semantics (same-IDs replay vs.
      `ALREADY_ONBOARDED` for a genuinely second attempt)
- [ ] Authentication enforced server-side (reuses `src/core/auth/session.ts`); no request body
      field is trusted for anything the server can derive from the verified JWT
- [ ] Error responses use the standard envelope with `ALREADY_ONBOARDED`/`VALIDATION_FAILED`
- [ ] Unit tests for the transaction (creates exactly 3 rows, idempotent replay, rejected second
      attempt) and an integration test proving the post-onboarding session refresh carries the
      correct `tenant_id` claim
- [ ] Cross-tenant negative test: tenant A cannot read tenant B's `stores` row (requires the new
      RLS policy above) — extends Sprint 01's manual two-tenant proof to a second table
- [ ] Tests pass **in CI** on an actual merged PR — not inferred from local success, per Sprint 01's
      retrospective rule
- [ ] No secret, token, or key written to logs
- [ ] Module registry ([modules/README.md](../modules/README.md)) updated to reflect Company &
      Store Setup's build status

**Explicitly not in this sprint's DoD subset:** mobile/offline/UI boxes (no Flutter client exists),
`PATCH /stores/{id}` (deferred past this sprint per the specification's §4), Roles & Permissions
(the signing-up user gets no formal role yet — a named scope boundary, not a gap).

## Demo script

1. Sign up a brand-new Supabase Auth identity (no existing `public.users` row).
2. Call `POST /api/v1/onboarding` with a tenant name, store name, and display name — show exactly
   one `tenants` row, one `stores` row, and one `users` row created.
3. Refresh the session — show the new JWT's `tenant_id` claim now matches the created tenant
   (it was absent immediately after signup, before this endpoint ran).
4. Replay the exact same request (same generated IDs) — show it returns the same result, not a
   duplicate or an error.
5. Attempt onboarding again from the *same* identity with freshly generated IDs — show
   `ALREADY_ONBOARDED`, not a second tenant.
6. As this tenant's session, attempt to read a different tenant's `stores` row by ID — show it is
   denied (empty result), the second table (after `tenants`) with a live cross-tenant proof.

## Retrospective

Recorded at close in [retrospective-log.md](retrospective-log.md), per
[sprint-cadence.md §2](sprint-cadence.md#2-ceremonies-kept--because-they-serve-scope-discipline-not-coordination) —
Sprint 01's own rule was "every other sprint, or immediately after any sprint with a real surprise";
whether this one gets a full entry depends on whether anything surprises us, decided honestly at
close, not pre-committed here.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-01 | Sprint 02 planned: `POST /api/v1/onboarding` (Company & Store Setup), 1.0 of ~3.75 person-day budget, most of the headroom explicitly allocated to the module-specification gap-filling already done at sprint open rather than left unaccounted. |
