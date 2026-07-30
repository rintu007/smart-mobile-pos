# Phase 15 — GitHub Project

> **Status:** 🔵 In review — all 9 deliverables drafted
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** CTO / DevOps Engineer

## Charter

| | |
| --- | --- |
| **Objective** | Set up the repository, project board, automation and delivery pipeline so that process is enforced by tooling rather than by memory. |
| **Inputs** | Phases 08 and 14 (both 🔵 In review). |

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`repository-setup.md`](repository-setup.md) | Branch protection incl. admins; solo-founder review gap named with a compensating control | 🔵 In review |
| [`project-board.md`](project-board.md) | 6-column board with a first-class Blocked column; 5 item types; 5 fields | 🔵 In review |
| [`issue-templates.md`](issue-templates.md) | 5 GitHub Issue Forms, each structurally scoped to its item type | 🔵 In review |
| [`pull-request-template.md`](pull-request-template.md) | Full Definition-of-Done checklist embedded verbatim | 🔵 In review |
| [`labels-and-milestones.md`](labels-and-milestones.md) | 6-axis label taxonomy; milestone naming fixed to release slices, dates deferred to Phase 16 | 🔵 In review |
| [`ci-workflows.md`](ci-workflows.md) | 3 workflow files; migration validation is fresh-database-only | 🔵 In review |
| [`cd-workflows.md`](cd-workflows.md) | Vercel one-merge deploy; Android signing via encrypted secrets; rollback mechanism per component | 🔵 In review |
| [`environments.md`](environments.md) | 4 environments; staging's own cost named as a concrete OD-02 input | 🔵 In review |
| [`code-quality-gates.md`](code-quality-gates.md) | Every merge-blocking gate from Phases 08/11/12/13/14, consolidated in one list | 🔵 In review |

## Exit criteria

- [x] `main` is protected: no direct pushes, required status checks, required review —
      [repository-setup.md §2](repository-setup.md#2-branch-protection-on-main), including admins.
- [x] CI runs lint, type-check and full test suite on every pull request in under ten minutes —
      [ci-workflows.md §1](ci-workflows.md#1-pryml--every-pull-request), sized against
      [ci-pipeline.md](../14-testing/ci-pipeline.md)'s existing budget.
- [x] Migrations are validated in CI against a fresh database —
      [ci-workflows.md §1](ci-workflows.md#1-pryml--every-pull-request)'s migration-validation step,
      always ephemeral, never a persisted/reused database.
- [x] Cross-tenant isolation tests are a required status check —
      [code-quality-gates.md §1](code-quality-gates.md#1-the-full-list-with-its-origin), named
      explicitly in the branch-protection required-checks list.
- [x] Secret scanning and dependency vulnerability scanning are enabled —
      [ci-workflows.md §2](ci-workflows.md#2-nightlyyml) (Dependabot) and
      [code-quality-gates.md §1](code-quality-gates.md#1-the-full-list-with-its-origin) (bundle scan).
- [x] Android builds are produced and signed automatically; signing keys are never in the repository —
      [cd-workflows.md §2](cd-workflows.md#2-android-build-signing-and-distribution) — keystore lives
      only as a GitHub encrypted secret.
- [x] The pull request template mechanically enforces the Definition of Done checklist —
      [pull-request-template.md](pull-request-template.md), the full checklist embedded verbatim.
- [~] A rollback procedure exists and has been rehearsed once, before it is needed — the procedure
      is fully specified in [cd-workflows.md §4](cd-workflows.md#4-rollback-procedure); **the actual
      rehearsal cannot happen inside a documentation phase** and is tracked forward to Phase 18,
      per [cd-workflows.md §5](cd-workflows.md#5-the-rehearsal--an-honest-gap-not-skipped) — the same
      honest treatment given to every other execution-only gap in this documentation set.

Seven of eight exit criteria are fully met by specification. The eighth (the rehearsal) is honestly
carried forward as pending execution, matching the standing pattern from Phases 10, 11, 12, and 14.

## Rules

- **If a rule matters, automate it.** A rule enforced only by review is a rule that will be missed
  on the day it matters most.
- Deployments are boring: one command or one merge, reversible, with no manual steps to forget.
- The build must be reproducible from a clean checkout by someone who has never built it before.
