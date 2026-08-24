# Sprint 67

> **Dates:** 2026-08-25 – 2026-08-25 (single-day, same cadence as every prior sprint)
> **Milestone:** none — repository-tooling fix, not M5/M4 backlog work (same class as Sprint 66)
> **Status:** Closed.

## Goal

Sprint 66 closed the lowest-risk of the three Dependabot PRs left open after the earlier triage
(`eslint-config-next` 16). This sprint closes the second: Vitest 4 (#58), confirmed contained to
test tooling — `vite` has never been a build-time dependency of `apps/web` (Next.js uses its own
bundler for `next build`, not Vite), so this change carries no risk to the actual production build
path.

## What was found

The prior triage's diagnosis ("Vitest 4 requires Vite 6+, peer dependency incompatibility") was
re-confirmed directly rather than re-derived from scratch, since it was already precise — unlike
Sprint 66's own eslint-config-next diagnosis, which needed correcting. `gh run view --log-failed`
on PR #58's own CI run confirms the exact failure:

```
Error [ERR_PACKAGE_PATH_NOT_EXPORTED]: Package subpath './module-runner' is not defined by
"exports" in .../vite@5.4.21.../package.json
```

`npm view vitest@4.1.11 peerDependencies` confirms Vitest 4 requires `vite: ^6.0.0 || ^7.0.0 ||
^8.0.0` — strictly. `pnpm why vite` showed `vite` was never a direct dependency of `apps/web` at
all; it was resolved transitively, entirely through Vitest 2's own dependency chain (`vite-node`,
`@vitest/mocker`). Bumping Vitest alone, with no explicit `vite` entry, leaves pnpm free to resolve
whatever transitive version satisfies the *old* Vitest's looser requirement — which is exactly what
produced the mismatch Dependabot's PR hit.

## What was built

`apps/web/package.json`: added `vite` as an explicit devDependency (`^8.2.2`, the current latest —
matching this session's own convention of taking the latest available version rather than the
minimum that satisfies the peer range, the same choice made for every other Dependabot bump merged
this run) and bumped `vitest` `^2.1.8` → `^4.1.11`.

No config changes were needed: all three `vitest.config*.ts` files (`vitest.config.ts`,
`vitest.integration.config.ts`, `vitest.integration.nightly.config.ts`) use only `defineConfig` and
plain `test`/`resolve.alias` options — no Vite plugins, no version-sensitive API surface that
changed across the major bump.

## Design decisions

1. **Pin `vite` explicitly rather than let it resolve transitively again.** The root cause of this
   PR's own failure was exactly the absence of an explicit `vite` entry — Dependabot's own diff only
   ever touched `vitest`, leaving `vite`'s resolved version to whatever the lockfile's prior state
   happened to pin. Adding it directly makes the dependency real rather than incidental, and gives
   Dependabot something to track and bump independently going forward.
2. **Did not chase the new "native config loader" deprecation warning.** `vitest run` now warns that
   `vitest.config.ts`'s ESM syntax loaded as CommonJS (no `"type": "module"` in `package.json`) is
   unsupported by a future default config loader. Real, but forward-looking and non-blocking today
   (`VITE_CONFIG_NATIVE_IGNORE_WARNING` isn't even needed to keep CI green) — named here rather than
   fixed speculatively, since renaming three config files or flipping the package's module type is a
   separate, deliberate change with its own blast radius, not something to fold into a dependency
   bump.
3. **No local integration-test run** — this repository has never had local Postgres/Docker
   infrastructure (Sprint 40's own text), and `fast-integration` has always been CI-only by design.
   Verified via the PR's own CI run instead, the same venue this project has always used for it.

## Definition of Done

- [x] `apps/web/package.json` — `vite` added (`^8.2.2`), `vitest` bumped to `^4.1.11`.
- [x] Verified locally: `lint` clean, `typecheck` clean, `test` 227/227, `prisma generate && build`
      (CI-style placeholder env vars) succeeds.
- [x] Verified in CI: `fast-integration` (the one venue this repo has for it) green on this PR.
- [x] `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md` updated in the
      same PR.
- [x] PR #58 (Dependabot) expected to self-close once `main` carries these versions.

## Demo script

**Local, run 2026-08-25:**

1. Confirmed the failure's exact error via `gh run view --log-failed` on PR #58's own CI run before
   writing any fix. ✅
2. Confirmed Vitest 4's real peer requirement via `npm view vitest@4.1.11 peerDependencies` rather
   than assumed from the error message alone. ✅
3. Confirmed `vite` was never a direct dependency via `pnpm why vite` — the actual mechanism behind
   the failure, not just its symptom. ✅
4. `pnpm install` — lockfile updated, `vite@8.2.2` now resolved directly. ✅
5. `pnpm --filter @smart-pos/web test` — 227/227 passing under Vitest 4. ✅
6. `pnpm --filter @smart-pos/web lint`/`typecheck` — both clean. ✅
7. `prisma generate && build` with CI's own placeholder env vars — succeeded. ✅

**Not performed, and deliberately not attempted this sprint:** the native-config-loader migration
(`"type": "module"` or `.mts` config files) the new deprecation warning names — real, forward-looking
future work, not something this bump needs today.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Two Dependabot-triage-derived fixes in a row (Sprints 66/67) have now each started by re-confirming
the prior session's own one-line diagnosis against the actual CI log rather than building directly
from memory — one diagnosis needed correcting, one didn't, and there was no way to know which in
advance without checking. Worth keeping as the default first step for #60 (Prisma 7) too, given its
materially larger blast radius (the one dependency here that actually touches every runtime request,
not just test tooling).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-25 | Sprint 67: closed Dependabot PR #58 (Vitest 4). Confirmed the prior triage's diagnosis was accurate — Vitest 4 requires Vite 6+ as a strict peer dependency, and `vite` had only ever been resolved transitively through Vitest 2's own dependency chain, never pinned directly. Added `vite` (`^8.2.2`) as an explicit devDependency alongside the `vitest` `^4.1.11` bump. No vitest.config.ts changes needed. `lint`/`typecheck`/`test` (227/227)/`build` all verified clean locally; `fast-integration` verified in CI. Named, not fixed: a new forward-looking "native config loader" deprecation warning, real but non-blocking. |
