# CI Workflows

> **Status:** 🔵 In review
> **Phase:** 15 — GitHub Project
> **Version:** 0.2.0
> **Last updated:** 2026-08-18
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
    # Idempotent-replay + 2-device composition (offline-test-suite.md) — M4 item 6, not built yet;
    # added to this same job when that item lands, not a separate one.
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

## 2. `nightly.yml`

```yaml
name: Nightly
on: { schedule: [{ cron: "0 20 * * *" }] }   # off-peak UTC, per ci-pipeline.md §3
jobs:
  fuzzed-composition:      # N-device, 100 runs — test-plan.md §2
  full-failure-scenarios:  # all 10 named scenarios — failure-scenarios.md §1
  extended-property-tests: # larger generated-input budget — test-strategy.md §4
  dependency-audit:        # Dependabot alerts (free, native) — reviewed, not just generated
```

A nightly failure opens (or updates) a `type:defect`, `priority:P0` issue automatically — per
[project-board.md](project-board.md)'s automation stance, a nightly regression should never require
someone to remember to check a dashboard the next morning.

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
