# Phase 02 — Business Requirements

> **Status:** 🔵 In review — all six deliverables drafted, two known gaps before 🟢 approval (see below)
> **Version:** 0.1.0
> **Last updated:** 2026-07-29
> **Owner:** Business Analyst / Product Manager

## Charter

| | |
| --- | --- |
| **Objective** | Translate the approved vision into numbered, testable business requirements describing *what the business needs*, independent of any solution. |
| **Inputs** | Approved Phase 01. [OD-04](../01-vision/open-decisions.md) (V1 scope) decided. [OD-01](../01-vision/open-decisions.md) (launch market) is **provisional** — India (GST) assumed pending founder confirmation. |
| **Blocked by** | Nothing — proceeding under the provisional market assumption so work is not stalled. **All tax, receipt-law, payment-method and currency content produced in this phase is provisional until OD-01 is confirmed**, and must be re-verified (not assumed correct) once the real market is confirmed. |

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`business-requirements.md`](business-requirements.md) | 54 numbered `BR-001`–`BR-054`, each with rationale, MoSCoW priority and testable acceptance criteria, across all 16 V1 modules | 🔵 In review |
| [`market-analysis.md`](market-analysis.md) | Provisional-market business practices, payment norms, connectivity reality, device landscape | 🔵 In review — provisional on OD-01 |
| [`regulatory-requirements.md`](regulatory-requirements.md) | 8 numbered `RR-001`–`RR-008`: tax model, mandatory fields, invoice numbering, data residency | 🔵 In review — provisional on OD-01, **not yet practitioner-reviewed** |
| [`competitor-analysis.md`](competitor-analysis.md) | Loyverse, Vyapar, Zoho POS, Marg ERP: pricing, gaps, why a shop would switch | 🟢 Approved — not market-provisional |
| [`cost-model.md`](cost-model.md) | Infrastructure cost per tenant per month, with a stated fixed floor and modelled variable costs | 🟡 Draft — usage assumptions unmeasured |
| [`pricing-strategy.md`](pricing-strategy.md) | Free-tier cap, ₹299/month paid recommendation, conversion-rate margin check | 🟡 Draft — pending willingness-to-pay validation |

Underlying sourced research lives in [docs/reference/](../reference/) — `vendor-limits.md`,
`regulatory-notes.md`, `competitor-teardown.md`, `device-landscape.md`, `payment-providers.md`.

## Exit criteria

- [x] Every V1 module traces to at least one `BR` — see [traceability table](business-requirements.md#traceability--every-v1-module-covered).
- [x] Every `BR` has testable acceptance criteria — no "should be fast", no "user friendly".
- [ ] **Regulatory requirements confirmed against a primary source, not memory.** Partially met:
      current research used secondary sources (tax-advisory blogs, aggregator sites), not primary
      government sources (CBIC/GST portal circulars). **Blocks 🟢 approval of this phase** until a
      qualified GST practitioner reviews `regulatory-requirements.md` — tracked in
      [reference/regulatory-notes.md](../reference/regulatory-notes.md#open-items-for-phase-02-proper--phase-07).
- [x] Cost model produces a defensible per-tenant monthly figure — see [cost-model.md §3](cost-model.md#3-worked-cost-per-tenant-at-different-scales). Fixed floor is vendor-sourced; variable costs are explicitly modelled, not measured.
- [x] Pricing covers cost with margin at the projected free-to-paid conversion rate — see [pricing-strategy.md §5](pricing-strategy.md#5-conversion-rate-target-and-margin-check) (>98% gross margin on infrastructure at a conservative 15% conversion).

**Remaining before this phase can be marked 🟢 Approved:**
1. Confirm [OD-01](../01-vision/open-decisions.md) — the launch market is still provisional.
2. Qualified GST practitioner review of `regulatory-requirements.md`.
3. Pilot willingness-to-pay input to replace the `pricing-strategy.md` recommendation with a
   validated figure (not blocking — Phase 03 can proceed on the current draft).

## Rules

- A business requirement states a **need**, never a solution. "The owner must know which stock is
  running out" is a requirement. "Add a low stock alerts screen" is a design.
- Every `BR` carries a MoSCoW priority. Priorities are assigned against the V1 boundary, not wishes.
- Requirement IDs are permanent and never reused.
