# Repository Setup

> **Status:** 🔵 In review
> **Phase:** 15 — GitHub Project
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** CTO / DevOps Engineer
> **Approved by:** _pending_

Monorepo initialisation, workspace tooling, and branch protection — turning
[monorepo-layout.md](../08-folder-structure/monorepo-layout.md)'s planned tree and
[ci-pipeline.md](../14-testing/ci-pipeline.md)'s planned gates into an actual repository
configuration. **This document specifies what the repository setup does; it does not itself
perform `git init` or create the GitHub repository** — per this project's standing rule that
implementation (Phase 18) is where code and infrastructure are actually created, one module at a
time, not scattered across documentation phases.

---

## 1. Initialisation

- A single GitHub repository (private, until a deliberate later decision to open-source any part of
  it — not the default) hosting the entire monorepo tree already fixed in
  [monorepo-layout.md §1](../08-folder-structure/monorepo-layout.md#1-top-level-tree).
- `pnpm-workspace.yaml` declares `apps/web` and `packages/contracts`; `apps/mobile` is outside the
  pnpm workspace entirely (it's a Flutter/Dart package, per
  [monorepo-layout.md §2](../08-folder-structure/monorepo-layout.md#2-workspace-tooling)) and is
  built via its own `pubspec.yaml` and Flutter tooling.
- `.gitignore` from the very first commit includes `.env.local`, `node_modules/`, Flutter's
  `.dart_tool/`/`build/`, and any local database files — per
  [secrets-management.md §2](../12-security/secrets-management.md#2-environment-variable-handling)'s
  own emphasis that this is a day-one convention, not a later cleanup task, since a secret committed
  once remains in git history even after deletion.

## 2. Branch protection on `main`

| Rule | Setting |
| --- | --- |
| Direct pushes | Disabled — every change reaches `main` through a pull request, no exceptions, including for the CTO |
| Required status checks | Every PR-gated stage from [ci-pipeline.md §2](../14-testing/ci-pipeline.md#2-pipeline-stages--every-pull-request) — lint/typecheck, import-boundary rules, unit tests, widget tests, fast integration tests (including the cross-tenant suite by name, per this phase's own exit criterion), bundle secret scan |
| Required review | At least 1 approving review before merge |
| Include administrators | **Yes** — the branch-protection rule applies to the repository owner too; per this phase's rule, "if a rule matters, automate it," a rule with an admin bypass is a rule that gets bypassed exactly when it matters most |
| Require branches up to date before merging | Yes — prevents merging a PR whose CI ran against a stale base |

## 3. The honest gap — solo-founder review, stated plainly rather than worked around

**Required review from a second person is not realistic for a genuinely solo founder/engineer
period.** Rather than quietly disabling the review requirement (which would violate §2's "include
administrators" stance) or inventing a fictional second reviewer, this document states the actual
interim compensating control: during any period with no second engineer, the sole contributor
**self-reviews against the Pull Request template's Definition-of-Done checklist**
([pull-request-template.md](pull-request-template.md)) as a separate, deliberate step before
merging — recorded in the PR itself (checked boxes are the evidence), not skipped silently. This is
weaker than genuine independent review and is named as weaker, not dressed up as equivalent — the
moment a second engineer joins, the required-review setting reverts to enforcing real independent
review, with no configuration change needed since the rule was never actually turned off.

## 4. Reproducibility from a clean checkout

Per this phase's rule, the build must be reproducible by someone who has never built it before —
concretely: a `README.md` at the repository root documents the exact setup sequence (install
`pnpm`, install the Flutter SDK at the pinned version, `pnpm install`, `flutter pub get`, environment
variable template via `.env.example`), and CI itself is the proof this works — every PR's fast
integration stage runs against a genuinely fresh checkout and fresh dependency install, not a cached
developer machine state, so "works in CI" and "works from clean" are the same claim, not two claims
that could silently drift apart.

## 5. Repository secrets — provisioned here, governed by Phase 12

The actual GitHub encrypted repository secrets ([secrets-management.md §2](../12-security/secrets-management.md#2-environment-variable-handling))
are created at Phase 18, when there is a real Supabase project and Vercel deployment to point them
at — this document fixes *that they will exist here, scoped this way* (per-environment, per
[environments.md](environments.md)), not their actual values, which do not exist yet.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Repository initialisation and branch-protection rules specified; solo-founder review gap stated honestly with a named compensating control rather than a silent bypass. |
