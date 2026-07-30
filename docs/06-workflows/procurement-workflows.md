# Procurement Workflows

> **Status:** ⚪ Deferred to V2
> **Phase:** 06 — Business Workflows
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Business Analyst / CTO
> **Approved by:** _N/A — deliberately not specified in this phase_

This document is a placeholder by design, not an oversight. Suppliers, Purchase Orders, and Goods
Receipt are **V2 modules** ([scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)) —
detailing their workflows now, before Phase 07 has even designed the V1 schema, would be exactly the
scope creep [project-vision.md §1](../01-vision/project-vision.md) and the phase discipline in
[ways-of-working.md](../00-governance/ways-of-working.md) exist to prevent.

**V1 receives stock through exactly two paths, already fully specified:** Opening Stock (WF-009)
and Stock Adjustment (WF-010), both in [inventory-workflows.md](inventory-workflows.md). Neither
requires a supplier or a purchase order to exist.

## What happens here, and when

When V2 planning begins, this document is authored in full, following the same structure as
[sales-workflows.md](sales-workflows.md) and [returns-workflows.md](returns-workflows.md) — Mermaid
diagram, numbered steps, failure paths, tap counts, and reversal paths for:

- WF-D05 — Supplier creation
- WF-D06 — Purchase order creation / approval
- WF-D07 — Goods receipt against a purchase order (including partial receipt and over/under-delivery)
- Supplier payment and outstanding-balance tracking

Tracked in [workflow-catalogue.md](workflow-catalogue.md) so this gap is visible now, not
rediscovered later.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Established as a deliberate placeholder; V1 stock-entry paths confirmed sufficient without procurement. |
