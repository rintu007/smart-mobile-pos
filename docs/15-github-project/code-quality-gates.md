# Code Quality Gates

> **Status:** 🔵 In review
> **Phase:** 15 — GitHub Project
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** CTO / DevOps Engineer
> **Approved by:** _pending_

The automated checks that block a merge, in one place — every gate named individually across
Phases 08, 11, 12, 13, and 14, assembled here as the single list [repository-setup.md](repository-setup.md)'s
branch protection actually enforces. Per this phase's rule, **if a rule matters, it is automated**;
this document is the proof that every rule this documentation set has stated "matters" actually has
an automated check behind it, not just a sentence asserting it.

---

## 1. The full list, with its origin

| Gate | Enforces | Specified in |
| --- | --- | --- |
| Lint / type-check | Code style, type safety | Standard tooling, no cross-reference needed |
| Import-boundary rules | Feature/layer isolation ([layering-rules.md](../08-folder-structure/layering-rules.md)); client code can never import server-only secrets ([secrets-management.md §3](../12-security/secrets-management.md#3-the-build-time-check--the-exit-criterions-actual-mechanism)) | Phase 08, Phase 12 |
| Unit test suite, 26-rule traceability | Every DR-NNN business rule has a passing automated test | [test-strategy.md §1](../14-testing/test-strategy.md#1-business-rule-traceability--the-exit-criterion-made-checkable) |
| Widget test suite | Every component's state matrix | [10-design-system](../10-design-system/README.md) |
| Cross-tenant isolation suite | All 22 tables + the Realtime extension | [tenant-isolation.md](../12-security/tenant-isolation.md) |
| Migration-against-fresh-database | A migration that only works on one machine is rejected | This phase's own exit criterion |
| Idempotent-replay + 2-device composition | Sync correctness, on every relevant PR | [offline-test-suite.md §3](../14-testing/offline-test-suite.md#3-ci-placement) |
| Bundle secret scan | No secret reaches a client bundle | [secrets-management.md §3](../12-security/secrets-management.md#3-the-build-time-check--the-exit-criterions-actual-mechanism) |
| SQL-injection lint rule (self-tested against a known-bad fixture) | No raw string-concatenated SQL | [security-test-plan.md §3](../14-testing/security-test-plan.md#3-injection) |
| Dependency vulnerability scanning | Known-vulnerable packages flagged | This phase's own exit criterion, via GitHub's native Dependabot (free) |

## 2. What is a merge gate vs. a release gate — restated as this phase's own binding list

Mirroring [ci-pipeline.md §5](../14-testing/ci-pipeline.md#5-what-blocks-a-merge-vs-what-blocks-a-release--stated-as-one-rule):
every row in §1 above is a **merge** gate, required on every pull request. The 10× load test,
physical-device performance budgets, and manual test scripts are **release** gates
([ci-workflows.md §3](ci-workflows.md#3-release-candidateyml--manually-triggered-or-on-a-release-branch-push),
[release-checklist.md](../14-testing/release-checklist.md)) — not weaker requirements, just gates
that fire at a different point because they require hardware or extended runtime a per-PR budget
cannot afford.

## 3. Coverage as a gate, specifically

Per [success-metrics.md](../01-vision/success-metrics.md)'s 90%-branch-coverage-on-domain-logic
target, restated in [test-strategy.md §3](../14-testing/test-strategy.md#3-coverage-targets): CI
asserts this threshold **on the domain/service-layer path specifically** (a named coverage scope in
the test runner's configuration, not a repository-wide percentage) — a PR that adds untested
business logic fails this gate even if the repository's *overall* coverage number would still look
acceptable, which is the entire point of scoping the target the way Phase 14 did.

## 4. No gate is bypassable, restated once more

Per [repository-setup.md §2](repository-setup.md#2-branch-protection-on-main)'s "include
administrators" setting: nothing in this list has an override switch reachable in the normal course
of work. The one named, honest exception — solo-founder review — is a *different* control
(§3 of [repository-setup.md](repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around)),
not a bypass of any gate in this document; every automated check in §1 still runs and still blocks,
regardless of how many humans are available to review.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Consolidated list of every merge-blocking automated gate with its originating phase; coverage-as-a-gate scoped to domain logic specifically; confirmed no gate in this list has a bypass. |
