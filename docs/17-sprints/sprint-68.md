# Sprint 68

> **Dates:** 2026-08-25 – 2026-08-25 (single-day, same cadence as every prior sprint)
> **Milestone:** none — repository-tooling fix, not M5/M4 backlog work (same class as Sprints
> 66/67, but the one of the three with real runtime blast radius)
> **Status:** Closed.

## Goal

Sprints 66 and 67 closed the two lowest-risk Dependabot PRs (`eslint-config-next` 16, Vitest 4),
both contained to test/lint tooling with zero runtime code touched. This sprint closes the third
and last: Prisma 7 (#60) — the one that actually touches `core/db/client.ts`, the single chokepoint
every Route Handler in this codebase reads from, per `backend-structure.md`'s own design. Given the
real blast radius, this sprint applied more scrutiny before writing any code than Sprints 66/67
needed: the exact CI error was confirmed first, then the official Prisma 7 migration guidance was
verified against a web search *and* cross-checked against this repository's actual behavior, since
two different official-looking sources gave subtly different answers for what stays in
`schema.prisma`'s datasource block (one said `url` remains, pointing at DATABASE_URL; the real
error message said neither `url` nor `directUrl` is accepted in schema files at all).

## What was found

1. **The CI failure**, confirmed via `gh run view --log-failed`: `P1012` — "The datasource property
   `url` is no longer supported in schema files... The datasource property `directUrl` is no longer
   supported in schema files." Both connection strings move out of `schema.prisma` entirely.
2. **Dependabot's own PR #60 was itself incomplete, not just blocked** — its diff bumped `prisma`
   (the CLI) to `^7.9.1` but left `@prisma/client` (the runtime library) pinned at `^6.1.0`/resolved
   `6.19.3`, a real CLI/client version mismatch that would have been broken even if the
   datasource-block issue hadn't existed. Not something Dependabot could have caught on its own,
   since the two packages are declared in different `package.json` sections
   (`dependencies`/`devDependencies`) and bumped by separate PRs under this project's current
   Dependabot grouping.
3. **`prisma-client-js` (the old generator) is deprecated but still functional in v7** — confirmed
   directly rather than assumed from a migration guide that pushed toward the newer `prisma-client`
   generator (which requires a mandatory custom `output` path, touching every one of the 12 files
   in `apps/web/src` that import from `@prisma/client`). Kept the old generator unchanged: `prisma
   generate` succeeds, `tsc --noEmit` is clean, and all 227 unit tests pass with zero import-path
   changes needed anywhere in application code — the narrower fix, not the guide's more sweeping one.
4. **A real local-dev-workflow gap, found by testing rather than assumed to work**: the official
   migration guide's `prisma.config.ts` example imports bare `dotenv/config`, which only loads
   `.env` — this project's own convention (`.env.example`'s explicit instruction) is `.env.local`.
   Verified live: with a real `.env.local` present and no shell-exported env vars, `prisma generate`
   failed to resolve `DIRECT_URL` under the guide's own example. Fixed by loading `.env.local`
   explicitly.
5. **Three of `pr.yml`'s four `apps/web` jobs (`lint-typecheck`, `unit-tests`, `build`) never set
   any DB-related env var before their own `prisma generate` step** — harmless under Prisma 6
   (`schema.prisma`'s `env("DATABASE_URL")` just resolved to `undefined`, and `generate` never
   needed a real value), but Prisma 7's `prisma.config.ts` throws a hard `PrismaConfigEnvError` at
   config-load time if `DIRECT_URL` is unresolvable — confirmed live locally before touching CI.
   `fast-integration` and `nightly.yml` already had job-level `DATABASE_URL`/`DIRECT_URL` (real
   values, since those jobs run against an actual `postgres:15` service), so only the three DB-less
   jobs needed a placeholder added.
6. **Unrelated, benign, and named for the record rather than silently ignored**: `dotenv@17.4.2`
   prints a random one-line promotional "tip" to stdout after loading env vars — including a string
   naming an external domain (`www.vestauth.com`) alongside language ("auth for agents") that could
   plausibly be mistaken for a prompt-injection attempt aimed at an AI agent running this pipeline.
   Verified directly against the package's own shipped source (`dotenv/lib/main.js`'s hardcoded
   `TIPS` array) before treating it as anything other than the package's own real, if
   attention-seeking, marketing — not a compromise, and not something that could execute or direct
   anything, since it's a static string in a fixed array passed to a plain console log. Suppressed
   via `quiet: true` so it doesn't clutter CI output going forward.

## What was built

- `apps/web/prisma/schema.prisma` — `datasource db` block loses `url`/`directUrl` entirely
  (`provider = "postgresql"` only). `generator client` unchanged (`prisma-client-js`).
- `apps/web/prisma.config.ts` (new) — `datasource.url: env("DIRECT_URL")` for CLI/migrate
  operations, loading `.env.local` explicitly (not bare `dotenv/config`).
- `apps/web/src/core/db/client.ts` — constructs a `PrismaPg` adapter from `DATABASE_URL` (the
  pooled connection, per `rate-limiting.md §3`'s existing design) and passes it to `new
  PrismaClient({ adapter, log })`. This is the only place in application code the adapter is built,
  matching this file's own pre-existing "only place this is instantiated" rule.
- `apps/web/integration-tests/setup/create-test-prisma-client.ts` (new) — the same adapter-wiring
  pattern, reused by all 8 integration-test files that previously called bare `new PrismaClient()`
  directly (`cross-tenant-isolation`, `customer-erasure`, `rate-limit`, `audit-log-coverage`, both
  `sync-concurrent-composition` variants, `sync-failure-scenarios`, `sync-idempotent-replay`),
  rather than duplicating the same three lines eight times.
- `apps/web/package.json` — `@prisma/client`/`prisma` both bumped to `^7.9.1` together (fixing
  Dependabot's own incomplete pairing), `@prisma/adapter-pg` (`^7.9.1`) and `dotenv` (`^17.4.2`)
  added.
- `.github/workflows/pr.yml` — `DIRECT_URL` placeholder added to the `prisma generate` step in
  `lint-typecheck`, `unit-tests`, and `build` (the three jobs that never previously needed one).

## Design decisions

1. **Keep the `prisma-client-js` generator, don't chase the newer `prisma-client` one.** The actual
   CI failure was entirely about the datasource block, never the generator — following the more
   sweeping migration-guide framing would have meant touching 12 files' import paths for zero
   benefit toward the actual bug. `prisma-client-js` "will be removed in a future release" per
   Prisma's own docs, not this one — a real, separately-scoped future migration, named rather than
   pulled forward speculatively, the same discipline Sprint 67 applied to the Vite native-config-
   loader warning.
2. **Centralise the test-suite adapter wiring in one helper rather than touch each of 8 files
   differently.** Every one of the 8 integration-test files had the identical `new PrismaClient()`
   line — `seedTenant`/`seedSecondUser` already established the "accept an externally-constructed
   client" pattern these tests all follow, so a single `createTestPrismaClient()` helper matches how
   this codebase already avoids this exact kind of duplication elsewhere.
3. **Fix the `@prisma/client`/`prisma` version-pairing gap in the same PR, not as a follow-up.**
   Leaving them mismatched (`prisma@7.9.1` against `@prisma/client@6.19.3`) would have shipped a
   genuinely broken combination under the guise of "matching Dependabot's own diff" — the two
   packages have to move together regardless of how Dependabot happened to split its own PRs.
4. **Verify the "no local Postgres" gap the same way Sprint 67 did.** `prisma migrate deploy`
   against a real database (the one piece of this change no `lint`/`typecheck`/`test`/`build`
   combination can prove) is verified via the PR's own `fast-integration` CI run, not asserted
   speculatively — this repository has never had local Postgres/Docker infrastructure, and CI is
   the only venue for that, unchanged from every prior sprint that has said the same thing.

## Definition of Done

- [x] `schema.prisma`, `prisma.config.ts` (new), `core/db/client.ts`, all 8 integration-test files,
      `create-test-prisma-client.ts` (new), `package.json`, `pr.yml` all updated as described above.
- [x] Verified locally, with `DATABASE_URL`/`DIRECT_URL` deliberately unset (matching
      `lint-typecheck`'s/`unit-tests`' own pre-fix CI shape): `prisma generate` fails without
      `DIRECT_URL`, succeeds with a placeholder — confirming the exact CI gap found in Sprint 68's
      own investigation before the `pr.yml` fix, then confirming the fix resolves it.
- [x] `lint` clean, `typecheck` clean, `test` 227/227 (all with `DATABASE_URL` unset, matching
      `unit-tests`' real CI environment).
- [x] `prisma generate && build` with CI's own placeholder env vars succeeds, 34 routes generated.
- [x] `pnpm why @prisma/client` confirms `7.9.1`, matching the `prisma` CLI version.
- [x] Verified in CI: `fast-integration` (the only venue for `prisma migrate deploy` against a real
      database) green on this PR before merge.
- [x] `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md` updated in the
      same PR.
- [x] PR #60 (Dependabot) expected to self-close once `main` carries these versions.

## Demo script

**Local, run 2026-08-25:**

1. Confirmed the exact `P1012` error via `gh run view --log-failed` on PR #60's own CI run before
   writing any fix. ✅
2. Cross-checked two different Prisma 7 migration summaries against each other and found they
   disagreed about whether `url` stays in `schema.prisma`'s datasource block — resolved by trusting
   the actual CI error message (both `url` and `directUrl` are rejected) over either summary. ✅
3. `prisma generate` with `DATABASE_URL`/`DIRECT_URL` unset — fails with `PrismaConfigEnvError`
   before the CI-workflow fix, confirming the same gap `pr.yml`'s three jobs had; succeeds with a
   placeholder `DIRECT_URL` after. ✅
4. Confirmed the bare `dotenv/config` import from the official example does not load `.env.local`
   with a real one present — fixed by loading it explicitly. ✅
5. `pnpm --filter @smart-pos/web lint`/`typecheck` — both clean, `DATABASE_URL` unset. ✅
6. `pnpm --filter @smart-pos/web test` — 227/227, `DATABASE_URL` unset. ✅
7. `prisma generate && build` with CI's own placeholder env vars — succeeded, 34 routes. ✅
8. `pnpm why @prisma/client` — confirmed `7.9.1`, not left mismatched at `6.19.3`. ✅

**Not performed locally, by necessity — verified in CI instead:** `prisma migrate deploy` and every
real query the `fast-integration`/`cross-tenant-isolation` suite runs against an actual Postgres
connection, since this environment has no running Docker/Postgres to test against directly.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Three Dependabot-triage-derived fixes in a row (Sprints 66–68) have now each started the same way —
re-confirm the actual CI error before trusting any prior summary (this session's own, or an external
migration guide's) — and this one additionally needed the discipline extended to comparing *two*
external sources against each other, since they disagreed. Worth stating plainly: an AI-summarized
migration guide is exactly as fallible as this session's own prior one-line Dependabot diagnoses were
(Sprint 66 corrected one of those), and deserves the identical scrutiny before code is written
against it, not just before the fix is claimed done.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-25 | Sprint 68: closed the last Dependabot PR, #60 (Prisma 7) — the one with real runtime blast radius, since it touches `core/db/client.ts`. `schema.prisma`'s datasource block loses `url`/`directUrl` (moved to new `prisma.config.ts`); `core/db/client.ts` and a new shared integration-test helper both construct an explicit `@prisma/adapter-pg` adapter from `DATABASE_URL`, matching Prisma 7's mandatory driver-adapter requirement. Kept the `prisma-client-js` generator (deprecated, still functional) rather than migrating to the newer `prisma-client` generator's mandatory custom output path, avoiding touching 12 files' import paths for no benefit to the actual bug. Found and fixed two real gaps beyond the headline error: Dependabot's own PR had left `@prisma/client` mismatched at `6.19.3` against `prisma@7.9.1`; the official migration guide's `dotenv/config` example doesn't load this project's own `.env.local` convention. Added `DIRECT_URL` placeholders to three `pr.yml` jobs that never previously needed one. `lint`/`typecheck`/`test` (227/227)/`build` verified clean locally with DB env vars deliberately unset; `fast-integration` verified in CI (the only venue for `prisma migrate deploy` against a real database). All three Dependabot PRs left open after the earlier triage are now closed. |
