# Sprint 01

> **Dates:** Started 2026-07-31
> **Milestone:** M0 — Walking Skeleton
> **Status:** In Progress — the Identity/Auth item (backlog item 2) is fully done: live Supabase project, schema migration, Custom Access Token Hook (Dashboard-wired), RLS on `tenants`/`users`, demo script run end-to-end and passed (see [implementation-log.md](../18-implementation/implementation-log.md)). The Repository/CI item (item 1) is not yet done: branch protection is unconfigured and `pr.yml` has never actually run (zero GitHub Actions runs on the repo so far) — both need the founder's direct GitHub access, no CLI/token substitute is available in this environment.

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
- [x] Schema documented (`prisma/schema.prisma`, `tenants`/`stores`/`users`) — [x] migration
      **applied** against the live Supabase database (`20260801050159_init` plus a corrective
      `20260801051705_fix_deferred_fk_delete_action`, see implementation-log.md), verified via
      `pg_constraint`; RLS enabled on `tenants`/`users`; the Custom Access Token Hook and
      `current_tenant_id()` functions are live and **wired in Dashboard → Authentication → Hooks**
- [x] Authentication enforced server-side — `src/core/auth/session.ts` is the only path that
      resolves a session; no client-side-only auth exists to accidentally rely on
- [x] Tests pass **locally** on a clean `pnpm install` (lint, typecheck, 2 unit tests, build all
      verified) — [ ] **in CI** still pending: `pr.yml` has never actually run (zero GitHub Actions
      runs on the repo) — needs a PR to actually open against `main`, which is entangled with
      branch protection (item 1, still a founder action)
- [x] No secret, token, or key written to logs — real secrets exist now (`.env.local`, gitignored)
      but are never committed, echoed into docs, or logged — verified via `git status`/diff review
      each time before any commit

## Demo script

1. From a clean checkout, run the documented setup sequence ([repository-setup.md §4](../15-github-project/repository-setup.md#4-reproducibility-from-a-clean-checkout)).
   **Not yet run** — depends on item 1 (branch protection, CI), still a founder action.
2. Open a pull request with no code changes (a scaffold commit) — show branch protection blocking a
   direct push to `main` and CI running and passing. **Not yet run**, same dependency as step 1.
3. Sign up a test user through Supabase Auth; inspect the issued JWT and show the `tenant_id` claim
   is present and correct. **Run 2026-08-01, passed** — decoded JWT's `tenant_id` claim matched the
   signed-up user's tenant exactly (see implementation-log.md for the two fixes this first real run
   surfaced: `security definer` on the hook function, `NO ACTION` instead of `RESTRICT` on the
   deferred circular FKs).
4. Attempt to read another tenant's `tenants` row with this session — show it is denied (the first
   real instance of [tenant-isolation.md](../12-security/tenant-isolation.md)'s guarantee, on real
   infrastructure for the first time). **Run 2026-08-01, passed** — empty result, not an error or a
   leak, after RLS was added to `tenants`/`users` (`supabase/sql/002_rls_tenants_users.sql`).

## Retrospective

Filled in at close, per [sprint-cadence.md §2](sprint-cadence.md#2-ceremonies-kept--because-they-serve-scope-discipline-not-coordination)
— not written in advance.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Sprint 01 planned: repository scaffold + Auth wiring, 3.0 of ~3.75 person-day budget, risks and reserved capacity named upfront. |
| 0.2.0 | 2026-08-01 | Live Supabase project provisioned; schema migration and Custom Access Token Hook function applied and verified against the real database. Dashboard hook wiring and the demo script are the remaining items. |
| 0.3.0 | 2026-08-01 | Founder wired the Dashboard hook; demo script steps 3–4 run and passed (fixed two real gaps: missing `security definer`, `RESTRICT` vs `NO ACTION` on the deferred FKs); RLS added to `tenants`/`users`. Identity/Auth item is fully done. Repository/CI item (branch protection, `pr.yml` actually running) remains a founder action — demo script steps 1–2 depend on it. |
