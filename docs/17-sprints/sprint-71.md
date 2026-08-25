# Sprint 71

> **Dates:** 2026-08-26 (single-day)
> **Milestone:** none — routine Dependabot triage, not milestone work
> **Status:** Closed.

## Goal

`dependabot.yml`'s weekly scan (Sprint 42) fired for the first time since the Sprint 65 triage and
Sprints 66–70's follow-up fixes, opening 7 new PRs (#96–#102). Triaged the same way as the original
12-PR batch: check each PR's own CI result before merging anything, rather than trust the version-
bump size as a proxy for risk.

## What was found

5 of 7 passed CI clean on the first check, including two major version bumps that turned out to be
non-breaking in practice: `next` 15.5.22→16.3.2 and `zod` 3.25.76→4.4.3. Merged as-is: `@supabase/ssr`
0.5.2→0.12.4, `next` 15.5.22→16.3.2, `build_runner`/`freezed`/`drift_dev` (mobile), `zod`
3.25.76→4.4.3, `sqlite3` 3.5.0→3.5.2 (mobile).

2 failed CI with genuine upstream compatibility gaps, neither fixable from this codebase's own side:

- **`typescript` 5.9.3→7.0.2 (#101):** `Error: typescript-eslint does not support TS 7.0.` —
  confirmed directly from the failing job's log. `@typescript-eslint` (the parser/plugin `eslint.config.mjs`
  depends on for type-aware linting) has not yet released support for TypeScript 7. Left open — there
  is nothing to configure or work around; this needs `@typescript-eslint` to ship support first.
- **`eslint` 9.39.5→10.9.0 (#102):** `TypeError: Error while loading rule 'react/display-name':
  contextOrFilename.getFilename is not a function` — a rule-context API this codebase doesn't call
  directly; it's inside `eslint-plugin-react`, bundled transitively through `eslint-config-next`'s
  native flat-config exports (Sprint 66). Left open for the same reason as #101 — the fix has to come
  from `eslint-plugin-react` (or `eslint-config-next` re-bundling a version of it) adding ESLint 10
  support, not from anything in this repository's own configuration.

## Design decisions

1. **Merge the 5 clean PRs without deeper manual review beyond CI passing.** Matches this project's
   own established practice throughout every prior Dependabot triage this session — the test suite
   and CI are the safety net; a green run across `lint`/`typecheck`/`unit-tests`/`fast-integration`/
   `build`/`mobile-analyze-test` is treated as sufficient basis for a routine dependency bump,
   including major versions, unless something concrete in the diff or changelog suggests otherwise.
2. **Leave #101/#102 open with no further action, rather than pin/downgrade/patch around them.**
   Both are genuinely blocked on an upstream package catching up to a very recent major release
   (TypeScript 7.0, ESLint 10.9.0, both current-generation releases) — not a misconfiguration in this
   repository. Forcing a workaround (e.g., disabling type-aware lint rules, pinning a transitive
   plugin version by hand) would trade a clean, well-understood wait for a fragile, harder-to-reason-
   about local patch, for no real benefit — nothing about staying on TypeScript 5.9/ESLint 9 blocks
   any other work.

## Definition of Done

- [x] #96, #97, #98, #99, #100 merged (`gh pr merge --squash --delete-branch`), each via the
      established `update-branch` sync + CI-reconverge cycle every merge in this sequence advances
      `main` past the next PR's base.
- [x] #101, #102 confirmed as genuine upstream blockers via their own failing CI logs, not left open
      on assumption.
- [x] `gh pr list --state open` confirms the expected final state: exactly #101/#102 remain.

## Demo script

**Local/CI, run 2026-08-26:**

1. Checked each of the 7 new PRs' own CI result via `gh pr checks` before touching any of them. ✅
2. For the 2 failures, read the actual failing-job log (`gh run view --log-failed`) rather than
   assumed the cause from the version-bump size alone. ✅
3. Confirmed the final open-PR state matches exactly what was intended (2 remaining, both diagnosed). ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Nothing new process-wise — this sprint is the same triage discipline established for the original
12-PR batch (Sprint 65), applied to the next weekly cycle. Worth noting only as a data point: two
major-version bumps (`next` 16, `zod` 4) passed clean while two more incremental-looking version
bumps (`typescript` 7.0, a `.0` release; `eslint` 10.9.0) hit real breaking changes — version-number
size alone remains a poor predictor of actual risk, the same lesson this project has drawn from every
Dependabot batch so far.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-26 | Sprint 71: triaged 7 new Dependabot PRs from `dependabot.yml`'s first weekly scan since Sprint 65. Merged 5 clean (`@supabase/ssr`, `next` 16, mobile build tooling, `zod` 4, `sqlite3` patch). Left 2 open with confirmed genuine upstream blockers: `typescript` 7.0 (`@typescript-eslint` doesn't support it yet) and `eslint` 10.9.0 (`eslint-plugin-react`, bundled via `eslint-config-next`, breaks on ESLint 10's rule-context API). No workaround attempted for either — both need the upstream package to catch up. |
