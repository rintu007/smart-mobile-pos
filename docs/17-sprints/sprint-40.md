# Sprint 40

> **Dates:** 2026-08-18 – 2026-08-18 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (backlog item 5 — cross-tenant
> isolation suite, CI-enforced)
> **Status:** Closed — M4 item 5 done. M4 now has items 6–9 remaining.

## Goal

Build the automated, CI-enforced cross-tenant negative-test suite
[tenant-isolation.md §2](../12-security/tenant-isolation.md#2-what-every-table-means-precisely-restated-as-a-checklist)/[§3](../12-security/tenant-isolation.md#3-ci-enforcement--not-a-one-time-proof-and-now-real)
has specified since Phase 12 but never had running code: real, authenticated negative tests against
every tenant-owned table, wired into `pr.yml` as a blocking stage — "not by inspection," per that
document's own §1 framing.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `fast-integration` CI job, cross-tenant isolation suite (all real tables), fixing any RLS gaps the suite itself finds | Cross-cutting (Security, CI/DevOps) | 3 | — |

## Design decisions, found while writing the spec

Full detail in [tenant-isolation.md §2/§3](../12-security/tenant-isolation.md).

1. **The "22 tables" figure was itself stale.** Cross-checked against the real, built
   `apps/web/prisma/schema.prisma` rather than trusted: 5 of the originally-listed tables
   (`product_variants`, `batches`, `idempotency_keys`, `sync_rejections`, `devices`) don't exist in
   the built schema; 2 real tables (`invoice_sequences`, `customer_field_conflicts`) were never
   listed at all; `user_store_roles` was miscategorised (it has its own direct `tenant_id` column,
   not a join-via-`users` shape). Corrected to the real count: **19**.
2. **A real, previously-undetected RLS gap: `sale_line_items`/`sale_payments`/`return_line_items`
   had no row-level security enabled at all**, contradicting tenancy-model.md §2's own parent-join
   policy template. `005_rls_sales.sql`/`015_rls_returns.sql`'s own comments had claimed this was
   deliberate ("access is always via `sale_id`/`return_id`, never queried directly across
   tenants"), relying solely on the API layer's own discipline — exactly the single point of
   failure RLS-as-defence-in-depth (ADR-0004, tenancy-model.md §3) exists not to depend on. Closed
   via two new migration files (`017_rls_sale_line_items_sale_payments.sql`,
   `018_rls_return_line_items.sql`), applying the exact template tenancy-model.md §2 already
   specified.
3. **No local/containerized Postgres or Supabase stack existed anywhere in this repo** — every
   prior "live verification" in this project has been a manual throwaway script run once against
   the shared production Supabase project, never CI-wired (correctly unsafe to run on every PR:
   state pollution, no isolation between concurrent PR runs, real credentials in CI). Resolved with
   a fresh `postgres:15` service container per CI run, `auth.jwt()` stubbed to exactly Supabase's
   own published implementation (the *only* `auth.*` function this codebase's RLS policies call,
   confirmed by grep) — real Postgres RLS enforcement, a real non-superuser `authenticated` role
   with no `BYPASSRLS`, real `SET LOCAL request.jwt.claims` per transaction, the same mechanism a
   real Supabase-issued JWT drives. Not a mock of RLS itself, only of the JWT-issuing step.
4. **The Realtime-channel extension (tenant-isolation.md §4) is deliberately deferred, not built.**
   A genuine test needs a running Realtime server — the full local Supabase CLI stack
   (`supabase start`: Postgres + GoTrue + PostgREST + Realtime), materially larger scope than a
   plain `postgres:15` container. Named as a real, tracked gap rather than silently dropped or
   faked.
5. **Documentation drift found and reconciled**: `tenant-isolation.md §3`, `security-test-plan.md
   §1`, and `ci-pipeline.md §2` variously said the suite runs "on every migration touching a
   tenant-owned table" or "on every PR, no path filter" — two different trigger conditions.
   Reconciled to what backlog item 5 actually asked for and what was actually built: every PR.

## Capacity check

3 person-days against estimate — landed on it. The infrastructure decision (found gap #3 above)
and the RLS gap (#2) were both real, unanticipated at decomposition time, but both were resolved
within the same pass rather than requiring a separate follow-up sprint.

## Reserved capacity

- [x] Defect capacity reserved: the `sale_line_items`/`sale_payments`/`return_line_items` RLS gap
      (#2 above) was a genuine pre-existing bug, found and fixed in the same pass, not deferred.
- [x] Documentation capacity reserved: `tenant-isolation.md`, `security-test-plan.md`,
      `ci-pipeline.md`, `ci-workflows.md`, backlog.md, this sprint doc, implementation-log, README
      bumps.

## Risks

- **None new for production data** — the suite runs against an ephemeral, per-CI-run database,
  never the shared production Supabase project; the two new RLS migration files are additive
  (`ENABLE ROW LEVEL SECURITY` + a `CREATE POLICY`, no data change) and were verified against the
  real applied SQL locally before being wired into CI.
- **Branch protection**: `fast-integration` is not yet in `main`'s required-status-checks list —
  adding it is a GitHub repository-settings change, outside what this session applies
  automatically; flagged for the founder to add once this PR's own `fast-integration` run is
  visible as a check.

## Definition of Done

- [x] `supabase/sql/017_rls_sale_line_items_sale_payments.sql`,
      `018_rls_return_line_items.sql` — the real, found RLS gap closed.
- [x] `apps/web/integration-tests/setup/auth-stub.sql` — the minimal `auth.jwt()` stand-in, the
      `authenticated`/`anon`/`supabase_auth_admin` roles the real SQL files reference.
- [x] `apps/web/integration-tests/setup/seed-tenant.ts` — a full, realistic fixture (one row per
      real table) for one tenant, transactional (the `Tenant`/`User` deferred-FK pair resolves
      correctly).
- [x] `apps/web/integration-tests/setup/apply-sql.mjs` — applies the auth stub then every
      `supabase/sql/*.sql` file, in order, via `pg` (simple query protocol — Prisma's own
      `$executeRawUnsafe` cannot run multi-statement files).
- [x] `apps/web/integration-tests/cross-tenant-isolation.test.ts` — 76 cases (19 tables × 4: a
      positive control plus read/update/delete negative tests), authenticated via `SET LOCAL ROLE
      authenticated` + `SET LOCAL request.jwt.claims` per transaction, always rolled back.
- [x] `apps/web/vitest.integration.config.ts` — a separate config from the default (mocked) unit
      suite; `vitest.config.ts` explicitly excludes `integration-tests/` so the existing
      `unit-tests` CI job (no database) is unaffected.
- [x] `.github/workflows/pr.yml` gains `fast-integration` — a `postgres:15` service container,
      migrations + RLS applied fresh, the suite run as a genuine blocking PR check.
- [x] Verified the suite is actually sensitive to a regression, not just trivially green:
      deliberately disabled RLS on `sale_line_items` locally and confirmed the suite fails; re-enabled
      and confirmed 76/76 pass again.
- [x] Full local dry run of the exact CI sequence (fresh container → `prisma generate` → `prisma
      migrate deploy` → `apply-sql.mjs` → `pnpm --filter @smart-pos/web test:integration`, all via
      the same `pnpm --filter` invocations `pr.yml` uses) — 76/76 passing.
- [x] `tsc --noEmit`/`eslint`/`vitest run` (209 total web unit tests, unaffected) all clean;
      production build confirmed before pushing.
- [x] `tenant-isolation.md`, `security-test-plan.md`, `ci-pipeline.md`, `ci-workflows.md` all
      updated in this PR — every found documentation-drift correction named above.
- [x] backlog.md, implementation-log, READMEs updated in the same PR.

## Demo script

**Local, run 2026-08-18**, mirroring `pr.yml`'s `fast-integration` job exactly:

1. Fresh `postgres:15` container, `pnpm --filter @smart-pos/web exec prisma generate` +
   `migrate deploy` → all 19 tables created. ✅
2. `node integration-tests/setup/apply-sql.mjs` → `auth-stub.sql` + all 18 `supabase/sql/*.sql`
   files applied cleanly, including the two new ones. ✅
3. `pnpm --filter @smart-pos/web test:integration` → 76/76 passing. ✅
4. Regression-sensitivity check: `ALTER TABLE sale_line_items DISABLE ROW LEVEL SECURITY` → the
   suite's `sale_line_items` cases fail (3/76) — proof the suite is a real gate, not a rubber stamp.
   Re-enabled → 76/76 passing again. ✅

**Full existing suites, run 2026-08-18**: `tsc --noEmit` — clean; `eslint` — clean; `vitest run`
(default/mocked suite) — 209/209 passing, unaffected by the new `integration-tests/` directory;
production build — succeeded.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the first sprint in
the project that found a real, load-bearing *security* gap (missing RLS on three tables) rather than
a UI/UX or documentation-currency gap — and found it specifically because it built the
"not by inspection" instrument tenant-isolation.md §1 has argued for since Phase 12, rather than
trusting the existing per-table comments' own claims. The self-test (deliberately breaking RLS and
confirming the suite catches it) is the same "prove the checker itself works" discipline
security-test-plan.md §3 already established for the SQL-injection lint rule — applied here for the
first time to this suite specifically.

M4 — Reports, Settings, and Release Readiness now has items 6–9 remaining, per
[backlog.md §5](backlog.md#5-m4--fully-decomposed-2026-08-16-now-that-m3-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-18 | Sprint 40 planned and built same-day: the cross-tenant isolation suite built and CI-wired (76/76 checks), a real RLS gap found and closed on 3 tables, the table-count/CI-placement documentation drift reconciled across 4 documents. M4 item 5 done, items 6–9 remain. |
