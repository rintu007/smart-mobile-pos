# CI Workflows

> **Status:** 🔵 In review
> **Phase:** 15 — GitHub Project
> **Version:** 0.4.0
> **Last updated:** 2026-08-19
> **Owner:** DevOps Engineer / CTO
> **Approved by:** _pending_

Lint, type-check, test, build, migration validation, and security scan — the actual GitHub Actions
workflow files implementing [ci-pipeline.md](../14-testing/ci-pipeline.md)'s three tiers. This
document specifies workflow **structure**; the files themselves are created in `.github/workflows/`
at Phase 18, against a real, initialised repository.

---

## 1. `pr.yml` — every pull request

```yaml
name: PR Checks
on: { pull_request: { branches: [main] } }
concurrency:
  group: pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true   # a new push supersedes an in-flight run — don't burn CI minutes on stale commits
jobs:
  lint-typecheck:
    # ESLint + TypeScript (apps/web), Dart analyzer (apps/mobile) — ci-pipeline.md §2
  import-boundaries:
    needs: lint-typecheck
    # dependency-cruiser (layering-rules.md) + client/server secret-boundary rule (secrets-management.md §3)
  unit-tests:
    needs: lint-typecheck
    # Full DR-001–DR-026 traceability suite (test-strategy.md §1)
  widget-tests:
    needs: lint-typecheck
    # 10-design-system component state-matrix tests
  fast-integration:
    needs: [lint-typecheck]
    # Cross-tenant isolation, all 19 real tables (security-test-plan.md §1) — built Sprint 40.
    # Idempotent-replay (3/3) + concurrent-composition non-fuzzed (4/4) + 1-of-10 server-testable
    # failure scenarios (offline-test-suite.md §3) — M4 item 6, built Sprint 41, same job.
  bundle-secret-scan:
    needs: [lint-typecheck]
    # secrets-management.md §3's content-scan mechanism
```

**Built Sprint 40 (backlog.md M4 item 5) — two corrections to this draft, found building it for
real:** `fast-integration` depends on `lint-typecheck` alone, not `unit-tests` — this draft
originally guessed the latter, but the two suites are independent (different database, different
code path) and ci-pipeline.md §2 itself already says stages "run in parallel where they have no
dependency on one another," so gating on `unit-tests` would only add latency for no correctness
benefit. And the table count is 19, not 22 — [tenant-isolation.md §2](../12-security/tenant-isolation.md#2-what-every-table-means-precisely-restated-as-a-checklist)'s
own dated correction, found in the same pass.

**Migration validation** runs inside `fast-integration` specifically as its own step: every PR
applies its migrations to a **freshly created** ephemeral test database (a `postgres:15` service
container, ephemeral to the job — never a persisted, reused, or shared/production one) before any
other test in that job runs — per this phase's exit criterion, "a migration that only works on the
developer's machine is not a migration," proven by never running a migration against anything
**but** a fresh database in CI.

## 2. `nightly.yml` — built Sprint 42 (backlog.md M4 item 7)

```yaml
name: Nightly
on: { schedule: [{ cron: "30 20 * * *" }], workflow_dispatch: {} }   # off-peak UTC, per ci-pipeline.md §3
jobs:
  nightly-integration:     # N-device fuzzed composition, 100 runs — test-plan.md §2, the only
                            # nightly-deferred content Sprint 41 actually produced
```

**Three corrections to this draft, found building it for real:**

1. **`full-failure-scenarios` and `extended-property-tests` have no code to run, on any tier.**
   `test-plan.md §3`'s Sprint 41 correction found only 1 of the 10 named failure scenarios is a
   server-testable case at all — it already gates every PR (`fast-integration`), so there is no
   separate "full" nightly superset of it; the other 9 need mobile `integration_test`
   infrastructure or the full local Supabase CLI stack, neither built. The property-based money/
   stock suite `test-strategy.md §4` describes was never built at all — confirmed by grepping for
   `fast-check` (or any property-testing library) anywhere in `apps/web`, finding nothing;
   `test-strategy.md §1`'s own traceability table is corrected in the same PR that added this file,
   since it had been claiming DR-008/DR-013 coverage from a suite that doesn't exist. Both are real,
   named, tracked gaps, not stubbed here ahead of having anything real to run — the same posture
   this file's own `pr.yml` section already established.
2. **Dependabot needs no job in this workflow at all** — `.github/dependabot.yml` (added the same
   PR) is sufficient on its own; vulnerability alerts run automatically once that file exists, and
   the weekly `open-pull-requests-limit` it sets is the version-currency half, independent of any
   CI run.
3. **`type:defect`/`priority:P0` (project-board.md §3's label taxonomy) don't exist in this
   repository** — found live running the failure-notification step for the first time; only
   GitHub's stock default labels do. Uses the stock `bug` label instead, a named, dated
   substitution — creating the full label taxonomy is project-board.md's own separate setup gap,
   out of this item's scope.

A nightly failure opens (or updates) a GitHub issue automatically (labelled `bug`/`nightly-failure`,
the latter newly created by the workflow itself on first use) — this project has no
`release-candidate.yml` yet either (§3 below, unbuilt), so "blocks the next release candidate"
(`ci-pipeline.md §3`'s own rule) has nothing to gate today; a visible, standing issue is this sprint's
actual answer to that rule's spirit for a solo-founder project with no release pipeline yet.

## 3. `release-candidate.yml` — manually triggered, or on a release-branch push

```yaml
name: Release Candidate
on: { workflow_dispatch: {}, push: { branches: ["release/**"] } }
jobs:
  load-test:          # 10x connection-pool test — rate-limiting.md §3 / performance-test-plan.md §3
  device-performance:  # requires a connected physical device or device farm runner — device-matrix.md
  build-artifacts:     # produces the signed Android build and the Vercel deployment preview — cd-workflows.md
```

Manual test scripts ([manual-test-scripts.md](../14-testing/manual-test-scripts.md)) are executed
by a human against this workflow's `build-artifacts` output, not automated within the workflow
itself — recorded per [release-checklist.md](../14-testing/release-checklist.md).

## 4. Required status checks, named exactly

Per [repository-setup.md §2](repository-setup.md#2-branch-protection-on-main), the branch-protection
required-checks list is exactly the job names in `pr.yml` §1 — `lint-typecheck`, `import-boundaries`,
`unit-tests`, `widget-tests`, `fast-integration`, `bundle-secret-scan` — named precisely so there is
no ambiguity between "the workflow exists" and "the workflow is actually a required gate," which are
two different GitHub settings that must be configured to agree.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Three workflow files structured (PR/nightly/release-candidate); migration validation specified as fresh-database-only; required-checks list named exactly against repository-setup.md's branch protection. |
| 0.2.0 | 2026-08-18 | **Retroactively added Sprint 41 — this row was missing despite the header already carrying this version.** Sprint 40 (backlog.md M4 item 5): `fast-integration` corrected to depend on `lint-typecheck` alone (not `unit-tests` — the two suites are independent, no correctness benefit from the added latency); table count corrected to 19, not 22 (tenant-isolation.md §2's dated correction); migration-validation paragraph updated to name the actual `postgres:15` service-container mechanism. |
| 0.3.0 | 2026-08-19 | Sprint 41 (backlog.md M4 item 6): `fast-integration`'s pseudocode comment updated — idempotent-replay/concurrent-composition/1-of-10 failure scenarios now built, in the same job, not deferred. |
| 0.4.0 | 2026-08-19 | Sprint 42 (backlog.md M4 item 7): §2 (`nightly.yml`) rewritten to match what's actually built — only the N-device fuzzed case has real content to run; `full-failure-scenarios`/`extended-property-tests` corrected to real, named, deferred gaps (no code exists for either, on any tier); Dependabot needs no job, only `.github/dependabot.yml`; the failure-notification labels corrected to the repo's actual (stock) label set. |
