# Phase 04 — Software Requirement Specification

> **Status:** 🔵 In review — all five deliverables drafted
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** CTO

## Charter

| | |
| --- | --- |
| **Objective** | Consolidate Phases 01–03 into the single authoritative engineering contract, and add the system-level specification that individual requirements do not cover. |
| **Inputs** | Phases 01–03 (all 🔵 In review — see [SRS Appendix C](srs.md#appendix-c--open-items-read-this-before-treating-anything-above-as-final) for the consolidated list of what's still provisional). |

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`srs.md`](srs.md) | The consolidated specification (IEEE 830 structure, adapted) | 🔵 In review |
| [`system-context.md`](system-context.md) | Context diagram: 7 actor rows, 7 named trust boundaries (TB-1–TB-7) | 🔵 In review |
| [`constraints.md`](constraints.md) | Technical, regulatory, operational and licence constraints, consolidated from Phases 00–03 | 🔵 In review |
| [`quality-attributes.md`](quality-attributes.md) | 10 scenarios (`QA-001`–`QA-010`), each stimulus → environment → response → measure | 🔵 In review |
| [`assumptions-and-dependencies.md`](assumptions-and-dependencies.md) | External/hardware dependency catalogue with degradation behaviour; 2 open questions flagged for Phase 13 | 🔵 In review |

## Exit criteria

- [x] SRS is internally consistent — no requirement contradicts another. One real inconsistency
      was caught and fixed during this phase: [user-stories.md](../03-functional-requirements/user-stories.md)
      used "Inventory Staff" as if it were a fourth system role; clarified as a job function
      operating under the Cashier/Manager roles actually defined in `DR-019`–`DR-021`.
- [x] Every quality attribute is expressed as a measurable scenario (stimulus → environment → response → measure), not an adjective — all 10 `QA`s follow the form.
- [x] Trust boundaries are explicit and feed directly into Phase 12 — 7 named boundaries (`TB-1`–`TB-7`) in [system-context.md](system-context.md#4-trust-boundaries--the-list-phase-12-inherits), including the finding that `TB-2` (Realtime) has no defence-in-depth fallback and RLS correctness is the *only* control there.
- [x] The SRS can be handed to an engineer who has read nothing else, and be sufficient — self-contained orientation in §1–2, with links out for full detail rather than duplication.

**Remaining before 🟢 Approved:** carries forward the same items as Phases 02–03 (OD-01
confirmation, GST-practitioner review), plus two new open questions this phase surfaced for Phase
13 (Realtime-outage fallback, local-storage-full behaviour) — see
[SRS Appendix C](srs.md#appendix-c--open-items-read-this-before-treating-anything-above-as-final).

## Rules

- The SRS supersedes conversation. If it is not in the SRS, it is not being built.
- Changes after approval require a major version bump and re-approval.
