# Sprint 01

> **Dates:** Started 2026-07-31
> **Milestone:** M0 — Walking Skeleton
> **Status:** In Progress — repository scaffold and Auth-wiring code complete and verified locally; live Supabase provisioning still pending (founder action, see [implementation-log.md](../18-implementation/implementation-log.md))

The one sprint this phase authors in full, per this document set's own "authored at planning, not
batch-authored ahead of time" convention — Sprint 02 is written once Sprint 01 actually closes.

## Goal

Stand up the repository and CI pipeline, and get a real user able to sign in against a real (dev)
Supabase project with a correctly tenant-scoped session.

## Scope

Backlog items 1–2 from [backlog.md §1](backlog.md#1-m0--walking-skeleton-fully-decomposed) — one
module only (Identity/Auth), well inside this phase's ≤2-module limit.

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Repository scaffold live: tree, branch protection, `pr.yml` green on an empty commit | Repository/CI | 1.5 | — |
| Supabase project (dev) provisioned; Auth wired with the Custom Access Token Hook injecting `tenant_id` | Identity | 1.5 | Repository scaffold |

## Capacity check

3.0 person-days of scope against a ~3.75 person-day sprint budget (midpoint pace, per
[sprint-cadence.md §1](sprint-cadence.md#1-sprint-length--2-weeks)) — 0.75 person-days of headroom,
allocated below rather than left as unaccounted slack.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-days — this is the *first* sprint against brand-new
      infrastructure, where a CI/branch-protection misconfiguration is the most likely thing to
      need same-sprint fixing, not deferral.
- [x] Documentation capacity reserved: 0.25 person-days — updating [modules/README.md](../modules/README.md)'s
      registry to reflect Identity module work actually starting, and correcting anything in
      [11-api/authentication.md](../11-api/authentication.md) that turns out to not match the
      Custom Access Token Hook's real, current configuration syntax (flagged since Phase 11 as
      pending Phase 18 verification — this is that verification).

## Risks

- **[R-10](../01-vision/risks-constraints-assumptions.md) (dependency abandonment)** — low
  likelihood this early, but the first real `pnpm install`/`flutter pub get` is where a stale or
  abandoned package would first surface.
- The Custom Access Token Hook's exact configuration was explicitly left unverified since Phase 11
  ([authentication.md §2](../11-api/authentication.md#2-issuance-flow)) — this sprint is where that
  assumption is tested against reality for the first time; if it doesn't work as documented, fixing
  the documentation is in scope for this sprint's reserved documentation capacity, not a separate
  follow-up.

## Definition of Done

Only the boxes this sprint's narrow scope can actually satisfy, per
[definition-of-done.md](../00-governance/definition-of-done.md) — explicitly **not** claiming the
full module checklist for a two-item slice:
- [x] Schema documented (`prisma/schema.prisma`, `tenants`/`users`) — [ ] migration **applied**
      still pending a real database (no Supabase project exists yet)
- [x] Authentication enforced server-side — `src/core/auth/session.ts` is the only path that
      resolves a session; no client-side-only auth exists to accidentally rely on
- [x] Tests pass **locally** on a clean `pnpm install` (lint, typecheck, 2 unit tests, build all
      verified) — [ ] **in CI** still pending a GitHub remote to actually run `pr.yml` against
- [x] No secret, token, or key written to logs — none exist yet to leak; the build uses only
      placeholder env values, per `.github/workflows/pr.yml`'s own comment

## Demo script

1. From a clean checkout, run the documented setup sequence ([repository-setup.md §4](../15-github-project/repository-setup.md#4-reproducibility-from-a-clean-checkout)).
2. Open a pull request with no code changes (a scaffold commit) — show branch protection blocking a
   direct push to `main` and CI running and passing.
3. Sign up a test user through Supabase Auth; inspect the issued JWT and show the `tenant_id` claim
   is present and correct.
4. Attempt to read another tenant's `tenants` row with this session — show it is denied (the first
   real instance of [tenant-isolation.md](../12-security/tenant-isolation.md)'s guarantee, on real
   infrastructure for the first time).

## Retrospective

Filled in at close, per [sprint-cadence.md §2](sprint-cadence.md#2-ceremonies-kept--because-they-serve-scope-discipline-not-coordination)
— not written in advance.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Sprint 01 planned: repository scaffold + Auth wiring, 3.0 of ~3.75 person-day budget, risks and reserved capacity named upfront. |
