# Sprint 66

> **Dates:** 2026-08-25 – 2026-08-25 (single-day, same cadence as every prior sprint)
> **Milestone:** none — repository-tooling fix, not M5/M4 backlog work (the same class as Sprint 42's
> Dependabot wiring: infrastructure this project depends on, not product scope)
> **Status:** Closed.

## Goal

With M5 decomposed (Sprint 65) and no further engineering content in that milestone, this session
triaged the 12 Dependabot PRs Sprint 42 had wired but never actually processed. 9 of 12 merged
cleanly; 3 were left open with confirmed real breaking changes needing dedicated migrations (#58
Vitest 4, #60 Prisma 7, #64 `eslint-config-next` 16). This sprint closes the lowest-risk of the
three: `eslint-config-next` 16, contained entirely to lint tooling with no runtime code touched.

## What was found

PR #64's CI failure was re-investigated rather than trusted at face value — the diagnosis on
record from the earlier Dependabot triage ("requires ESLint flat-config format") was checked
against the actual repository state and found to be imprecise: `apps/web/eslint.config.mjs` was
**already** a flat config file. The real cause, confirmed via the failing job's stack trace
(`@eslint/eslintrc`'s `ConfigValidator.formatErrors`, `TypeError: Converting circular structure to
JSON`) plus a web search against the actual upstream issue
([vercel/next.js#85244](https://github.com/vercel/next.js/issues/85244)): `eslint-config-next` 16
still ships `next/core-web-vitals` as a legacy-format shareable config for backward compatibility,
but that legacy config now includes `eslint-plugin-react-hooks`, whose own config object contains a
circular self-reference. `FlatCompat` (the `@eslint/eslintrc` compatibility shim this config was
using to load the legacy string into a flat array) chokes trying to validate and serialize that
circular structure for an error message. `eslint-config-next` 16 ships genuine native flat-config
exports specifically to route around this — `eslint-config-next/core-web-vitals` and
`eslint-config-next/typescript` — which this repository simply wasn't using yet.

The dependency bump itself was never the problem: the earlier triage's own lockfile diff shows
`eslint-config-next@16.3.2` resolves and installs cleanly against this repo's existing `next@15.1`/
`eslint@9.17` versions. No peer-dependency conflict, unlike Vitest 4/Vite 6 or Prisma 7's config
migration.

## What was built

`apps/web/eslint.config.mjs` rewritten to import and spread the native flat-config exports directly,
dropping `FlatCompat` (and its now-unused `@eslint/eslintrc` dependency) entirely:

```js
import nextCoreWebVitals from "eslint-config-next/core-web-vitals";
import nextTypescript from "eslint-config-next/typescript";

const eslintConfig = [
  ...nextCoreWebVitals,
  ...nextTypescript,
  {
    ignores: [".next/**", "node_modules/**", "src/generated/**", "next-env.d.ts"],
  },
];
```

`apps/web/package.json`: `eslint-config-next` bumped `^15.1.0` → `^16.3.2`; `@eslint/eslintrc`
removed (grepped first — confirmed unused anywhere else in `apps/web`).

## Design decisions

1. **Fix on a fresh branch against `main`, not by pushing to Dependabot's own PR branch.** Matches
   this session's own established convention (every other merged change this run of sprints went
   through a `sprint-NN-*` branch and PR). Dependabot detects `main` already carries its target
   version and closes PR #64 on its own, the same self-closing behaviour already observed for #61
   (`freezed`) during the earlier triage.
2. **Drop `FlatCompat` entirely rather than keep it for anything else.** Nothing else in
   `eslint.config.mjs` used it — the only reason it existed was to load `next/core-web-vitals`/
   `next/typescript`, and v16's native exports are now the documented, supported way to do exactly
   that. Keeping an unused compatibility shim around would just be latent risk for the next major
   bump.
3. **Verify beyond CI's own three checks.** `lint`, `typecheck`, and `test` (227/227) all confirmed
   clean locally, plus a full `prisma generate && next build` with the same CI-style placeholder env
   vars `pr.yml`'s `build` job uses — this project's own standing convention for every server-side
   change, applied here even though this change never touches runtime code, since a lint-config
   rewrite is exactly the kind of change that can silently break a build in ways `lint`/`typecheck`
   alone wouldn't catch.

## Definition of Done

- [x] `apps/web/eslint.config.mjs` — native flat-config exports, `FlatCompat` removed.
- [x] `apps/web/package.json` — `eslint-config-next` bumped to `^16.3.2`, `@eslint/eslintrc` removed.
- [x] Verified: `pnpm --filter @smart-pos/web lint` clean (0 errors — the circular-JSON crash is
      gone); `typecheck` clean; `test` 227/227; `prisma generate && build` succeeds with CI-style
      placeholder env vars, 34 routes generated.
- [x] `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md` updated in the
      same PR.
- [x] PR #64 (Dependabot) expected to self-close once `main` carries `eslint-config-next` 16 —
      confirmed after merge, not assumed.

## Demo script

**Local, run 2026-08-25:**

1. Reproduced the failure's real root cause via `gh run view --log-failed` on PR #64's own CI run,
   rather than trusting the prior session's summary framing verbatim. ✅
2. Confirmed `eslint.config.mjs` was already flat-config format before assuming a bigger migration
   was needed — the actual fix is narrower than "migrate to flat config" implied. ✅
3. `pnpm install` — 67 packages added, lockfile updated. ✅
4. `pnpm --filter @smart-pos/web lint` — clean, 0 errors (previously: crash). ✅
5. `pnpm --filter @smart-pos/web typecheck` — clean. ✅
6. `pnpm --filter @smart-pos/web test` — 227/227 passing. ✅
7. `prisma generate && pnpm --filter @smart-pos/web build` with CI's own placeholder env vars —
   succeeded, 34 API routes generated. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Worth naming: the prior session's own triage diagnosis ("requires ESLint flat-config format") was
close but not quite right — this repo was already on flat config; the real gap was narrower
(legacy-shape shareable configs loaded through a compatibility shim, not the flat-config format
itself). Re-deriving the root cause from the actual stack trace before writing any fix, rather than
trusting a one-line prior summary, is the same discipline this run of sprints has applied to design
docs all along, extended here to a prior triage note of my own.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-25 | Sprint 66: fixed `eslint-config-next` 16's `FlatCompat`/circular-JSON crash by migrating `eslint.config.mjs` to the package's native flat-config exports, unblocking Dependabot PR #64. Root cause was narrower than the prior session's own diagnosis — this repo was already on flat config; the actual issue is `next/core-web-vitals`'s legacy shareable-config shape colliding with `eslint-plugin-react-hooks`'s self-referential config object inside `FlatCompat`. `lint`/`typecheck`/`test` (227/227)/`build` all verified clean. |
