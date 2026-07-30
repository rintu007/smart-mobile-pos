# Competitor Analysis

> **Status:** 🟢 Approved (not market-provisional — see note)
> **Phase:** 02 — Business Requirements
> **Version:** 1.0.0
> **Last updated:** 2026-07-29
> **Owner:** Product Manager
> **Approved by:** CTO, 2026-07-29

Raw teardown with sources is in [reference/competitor-teardown.md](../reference/competitor-teardown.md).
This document turns that research into what a shop would need to see to switch, and what that
implies for our requirements.

**Note on provisionality:** unlike the other Phase 02 documents, this one is *not* fully
invalidated if OD-01 resolves to a different market — Loyverse and Zoho are global/regional
players, and the underlying positioning gap (nobody combines true offline-first, POS speed, tax
compliance and mobile-native design) is likely to hold in most candidate markets. Vyapar and the
India-specific tax detail would be swapped for local equivalents; the competitive *shape* would not.

---

## Why a shop currently on a competitor would switch

| From | Because they're missing | Requirement this implies |
| --- | --- | --- |
| Notebook / no software | Everything — this is the largest addressable group, not really "competitor switching" | Ten-minute onboarding promise ([project-vision.md §12](../01-vision/project-vision.md)) must actually hold, since this segment has zero switching cost tolerance |
| Loyverse | True offline guarantee (best-effort sync, not architectural); no customer-facing QR ordering; procurement depth | BR set must include an explicit, testable offline guarantee — not "works offline sometimes" |
| Vyapar | Not built for counter-speed selling; accounting-first UX | POS module's tap-count budget (≤3 taps, [success-metrics.md](../01-vision/success-metrics.md)) is a genuine differentiator, not a nice-to-have |
| Zoho POS | Forces adoption of the whole Zoho ecosystem; not offline-first | Product must work as a standalone app with no forced adjacent-product adoption |
| Marg ERP | Desktop-rooted, one-time-licence friction, steep learning curve for a single-owner shop | Mobile-native design and zero-technical-knowledge onboarding are the switching lever here, not price |

## Where competitors are ahead of our V1 plan — deliberately accepted gaps

| Competitor strength | Our V1 status | Why we accept the gap |
| --- | --- | --- |
| Loyverse's free-forever core tier | Our free tier is capped, not unlimited | We cannot out-free Loyverse on price; our wedge is offline guarantee + compliance + speed, not free-tier generosity. Pricing detail in [pricing-strategy.md](pricing-strategy.md). |
| Vyapar's GST filing/accounting depth | We explicitly export rather than replace accounting, per [project-vision.md §6](../01-vision/project-vision.md) | Competing with an accounting-first incumbent on accounting depth is a different company |
| Marg ERP's batch/expiry/serial tracking | Deferred to V4 | Vertical-specific depth before the horizontal core is proven is exactly the scope trap [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md) is designed to avoid |
| Zoho's full back-office suite (CRM, accounting, inventory) | We are deliberately narrower | Suite breadth is not the target segment's actual unmet need — a fast, reliable till is |

## Requirements this analysis feeds forward

Traced into [business-requirements.md](business-requirements.md):

- BR-001 (ten-minute onboarding) — driven by the "notebook" segment's zero switching-cost tolerance.
- BR-003, BR-004 (offline guarantee as an architectural property, not best-effort) — driven by the
  Loyverse gap.
- BR-010–BR-013 (POS tap-count and speed requirements) — driven by the Vyapar gap.
- BR-002 (GST-aware setup) — driven by the Vyapar strength we must match, not exceed, in V1.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 1.0.0 | 2026-07-29 | Initial analysis, approved — positioning conclusions are not market-provisional. |
