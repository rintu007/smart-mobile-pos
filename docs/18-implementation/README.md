# Phase 18 — Implementation

> **Status:** ⚪ Not started
> **Version:** 0.0.0
> **Last updated:** 2026-07-28
> **Owner:** CTO / All engineering roles

## Charter

| | |
| --- | --- |
| **Objective** | Build SmartPOS X, one complete module at a time, against approved specifications. |
| **Inputs** | Approved Phases 01–17. |

## The module loop

Every module, without exception, follows this sequence:

```
1. Author the module specification in docs/modules/<module>/  (all 11 sections)
2. Review and approve the specification
3. Write the database migration and Row Level Security policies
4. Implement the API: validation → service → repository
5. Write API tests, including authorisation and cross-tenant isolation
6. Implement the local schema and the offline queue behaviour
7. Implement the domain layer and its unit tests
8. Implement the interface and its widget tests
9. Write the integration test for the primary end-to-end workflow
10. Write the offline → online sync test, including a conflict
11. Verify against the Definition of Done — every box
12. Update all affected documentation
13. Merge
```

**Steps are not reordered and none are skipped.** In particular, the specification is written
before the code, not reverse-engineered from it afterwards.

## Deliverables

| Document | Content |
| --- | --- |
| `implementation-log.md` | Module-by-module record: dates, decisions, deviations, lessons |
| `coding-standards.md` | Dart and TypeScript conventions, lint configuration, formatting |
| `error-handling.md` | Error taxonomy, propagation, user-facing messages, logging and redaction |
| `performance-playbook.md` | Query patterns, list virtualisation, image handling, startup budget |
| `troubleshooting.md` | Known issues and their resolutions, grown as we encounter them |

## Module build order

Ordered so that each module can be genuinely completed and demonstrated using only what precedes
it. The order is fixed at Phase 16 against the dependency graph and recorded in
[docs/modules/README.md](../modules/README.md).

The **first** module is always the vertical slice from Phase 16: authenticate → add a product →
sell offline → sync → print. It touches every architectural layer while changing course is still
cheap.

## Exit criteria per module

The [Definition of Done](../00-governance/definition-of-done.md), in full. There is no partial credit.

## Rules

- **No placeholder code.** No `TODO`, no stub, no "wire this up later". A module that is not
  finished is not merged.
- **No module starts before the previous one is done.** Parallel half-modules produce integration
  debt that is paid at the worst time.
- **Deviations from the specification update the specification** — in the same pull request, with
  the reasoning. The documentation is the source of truth; silent divergence ends that.
- **Every implementation-time decision of consequence becomes an ADR.** If you had to think about
  it for more than ten minutes, someone will have to think about it again later.
