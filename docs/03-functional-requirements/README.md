# Phase 03 — Functional Requirements

> **Status:** 🔵 In review — all five deliverables drafted
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Product Manager / CTO

## Charter

| | |
| --- | --- |
| **Objective** | Specify what the system does, feature by feature, so that each statement is independently verifiable by a test. |
| **Inputs** | Phase 02 business requirements (🔵 In review — see [note](../02-business-requirements/README.md)). |

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`functional-requirements.md`](functional-requirements.md) | 84 `FR-001`–`FR-084`, grouped to mirror the BR groups, each tracing to a `BR` | 🔵 In review |
| [`non-functional-requirements.md`](non-functional-requirements.md) | 26 `NFR-001`–`NFR-026`: performance, availability, security, accessibility, device support, each with a measurement method | 🔵 In review |
| [`user-stories.md`](user-stories.md) | 28 `US-001`–`US-028` in persona/goal/benefit form | 🟡 Draft — personas provisional pending Phase 05 |
| [`business-rules.md`](business-rules.md) | 26 `DR-001`–`DR-026`: stock, tax/money, returns eligibility, permissions, sync/idempotency, audit — each stated as a verbatim-testable assertion | 🔵 In review |
| [`traceability-matrix.md`](traceability-matrix.md) | Full `BR → FR → US` matrix plus per-module coverage check | 🔵 In review |

## Exit criteria

- [x] Every `FR` traces to a `BR` — verified, zero orphaned FRs (see [traceability-matrix.md](traceability-matrix.md)).
- [x] Every `BR` in the V1 scope has at least one `FR` — 54/54 confirmed.
- [x] Every `NFR` has a number and a measurement method — all 26 do.
- [x] Business rules are stated so that each can become a unit test verbatim — all 26 `DR`s carry an `assert`-form statement.
- [x] The ten-minute onboarding promise is decomposed into per-step `FR`s with time budgets — FR-001–FR-006.

**Remaining before this phase can be marked 🟢 Approved:** carries forward Phase 02's two open
items (OD-01 confirmation, GST-practitioner review) since several FRs/RRs depend on them, plus
formal review/sign-off of the five documents above.

## Rules

- A functional requirement describes behaviour, not interface. Screens belong to Phase 10.
- Every requirement is atomic. A requirement containing "and" is usually two requirements.
- Offline behaviour is specified **per requirement** — what happens with no connectivity is part of
  the requirement, not an afterthought handled globally.
