# Infrastructure Cost Model

> **Status:** 🟡 Draft — model with stated assumptions, not yet measured
> **Phase:** 02 — Business Requirements
> **Version:** 0.1.0
> **Last updated:** 2026-07-29
> **Owner:** CTO
> **Approved by:** _pending — usage assumptions must be validated against real pilot data before this is treated as final (see [A-08](../01-vision/risks-constraints-assumptions.md))_

Required before [pricing-strategy.md](pricing-strategy.md), per this phase's exit criteria. Vendor
figures are sourced in [reference/vendor-limits.md](../reference/vendor-limits.md); this document
adds per-tenant usage assumptions to produce a per-shop monthly figure, and states those assumptions
explicitly so they can be replaced with measured data rather than mistaken for fact.

---

## 1. Fixed platform floor — solid numbers, independent of tenant count

Per [ADR-0002](../adr/ADR-0002-hosting-posture-for-commercial-launch.md), commercial launch runs on
paid tiers regardless of usage, because the free-tier licence and pause-on-inactivity problems in
[R-01](../01-vision/risks-constraints-assumptions.md) are not solved by staying inside a resource
limit.

| Line | Cost | Source |
| --- | --- | --- |
| Vercel Pro (1 seat) | $20.00/month | [vendor-limits.md](../reference/vendor-limits.md#vercel) |
| Supabase Pro (base) | $25.00/month | [vendor-limits.md](../reference/vendor-limits.md#supabase) |
| Domain (.in, amortised) | ~$0.60/month (~₹600/year) | [vendor-limits.md](../reference/vendor-limits.md#distribution) |
| Google Play (one-time, amortised over 24 months) | ~$1.00/month | [vendor-limits.md](../reference/vendor-limits.md#distribution) |
| **Fixed floor, total** | **≈ $46.60/month** (~₹3,960/month at an approximate ₹85/USD orientation rate — not a budgeting-grade FX figure) | |

This floor is paid **regardless of whether we have 1 tenant or 1,000** — it is the cost of existing
in production at all.

## 2. Variable cost per tenant — modelled, not yet measured

Included allowances beyond the base fee, and the overage rate once exceeded:

| Resource | Included in Pro | Overage rate | Source |
| --- | --- | --- | --- |
| Database storage | 8 GB | $0.125/GB | [vendor-limits.md](../reference/vendor-limits.md#supabase) |
| File storage | 100 GB | (not separately confirmed in this pass — flagged) | |
| Egress (Supabase) | 250 GB/month | $0.09/GB | [vendor-limits.md](../reference/vendor-limits.md#supabase) |
| Bandwidth (Vercel) | 1 TB/month + $20 credit | $0.15/GB after credit exhausted | [vendor-limits.md](../reference/vendor-limits.md#vercel) |
| Function execution (Vercel) | 1,000 GB-hours + credit | $0.128/CPU-hour, $0.0106/GB-hour | [vendor-limits.md](../reference/vendor-limits.md#vercel) |

### Modelling assumptions — **these are estimates, not measurements**

| Assumption | Value | Basis |
| --- | --- | --- |
| Database growth per shop per month | 10 MB | Rough estimate: ~150 sales/day × 30 days, multiple line items per sale, plus stock movements, at typical small-row transactional record sizes. **Not measured.** |
| Product-image storage per shop | 30 MB (one-time-ish, grows slowly with catalogue changes) | ~200 products × ~150 KB average compressed image. **Not measured.** |
| Egress per shop per month | 100 MB | Sync traffic (deltas, not full re-pulls) plus occasional report/receipt fetches. Product images served via signed URLs direct from storage per [ADR-0001](../adr/ADR-0001-hybrid-api-and-direct-realtime-access.md), which keeps this off the Vercel bandwidth line entirely. **Not measured.** |
| Vercel bandwidth/function load per shop | Not separately modelled | JSON API payloads are small relative to the 1 TB / 1,000 GB-hour included allowance; expected to stay within the included tier well past pilot scale. Revisit once real request volumes exist. |

**These four numbers are the load-bearing assumptions of this entire model.** They must be replaced
with measured figures from the pilot (per [A-08](../01-vision/risks-constraints-assumptions.md) and
[success-metrics.md §5](../01-vision/success-metrics.md), "infrastructure cost per active shop per
month") before this document can be marked 🟢 Approved.

## 3. Worked cost per tenant at different scales

Database storage compounds monthly (sales history is append-only and never deleted, by design —
[project-vision.md §9](../01-vision/project-vision.md)); the table below shows the position after
12 months of accumulated data at each tenant count, which is the more honest number than a
month-one snapshot.

| Tenant count | DB (12mo accumulated) | DB overage cost | File storage | Egress/month | Fixed floor | **Total/month** | **Per shop/month** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 20 (pilot) | 2.4 GB | $0.00 (within 8 GB) | 0.6 GB | 2 GB | $46.60 | **$46.60** | **$2.33** |
| 100 | 12 GB | $0.50 | 3 GB | 10 GB | $46.60 | **$47.10** | **$0.47** |
| 500 | 60 GB | $6.50 | 15 GB | 50 GB | $46.60 | **$53.10** | **$0.11** |
| 2,000 | 240 GB | $29.00 | 60 GB | 200 GB | $46.60 | **$75.60** | **$0.04** |

File storage and egress stay comfortably inside the Pro allowances at every scale modelled here.
**Database storage overage is the dominant variable cost driver at scale** — a direct consequence of
the append-only stock and sales ledger never deleting historical data. This is an accepted cost of
correctness (Principle 2, "the sale is sacred"), not a defect, but it is worth flagging now: a data
retention/archival strategy for old ledger data becomes a real cost-optimisation lever at large
scale, not just a compliance question. Not a V1 concern.

## 4. A finding this model surfaces for the still-open multi-tenancy ADR

[docs/adr/README.md](../adr/README.md) lists "multi-tenancy model (shared schema vs
schema-per-tenant)" as still open, forced by Phase 07. **This cost model makes that decision
largely make itself:** Supabase bills **per project**, with a $25/month minimum on Pro. A
schema-per-tenant model would mean paying at least $25/month *per tenant* — the free-tier cost
structure this entire pricing exercise depends on simply does not exist at that granularity. Shared
schema with row-level tenant scoping (already the direction implied by
[ADR-0001](../adr/ADR-0001-hybrid-api-and-direct-realtime-access.md)'s reliance on RLS) is the only
economically viable option under this vendor's pricing model. Recorded here as an input to that
ADR, not as a decision made by this document.

## 5. What is not yet in this model

- Payment gateway fees — deliberately excluded, they are transaction-linked variable revenue costs
  for V3, not fixed infrastructure costs. See [reference/payment-providers.md](../reference/payment-providers.md).
- Push notification cost — assumed free (Firebase Cloud Messaging) but **not independently
  re-verified** in this research pass; flagged in [vendor-limits.md](../reference/vendor-limits.md#push-notifications).
- Support/human cost per tenant — out of scope for an infrastructure cost model, but relevant to
  the eventual full unit-economics picture in [pricing-strategy.md](pricing-strategy.md).
- Map tile costs (V3 only) — see [vendor-limits.md](../reference/vendor-limits.md#map-tiles-openstreetmap-community-servers).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-29 | Initial model. Fixed floor is sourced; per-tenant variable costs are estimated and flagged for pilot validation. |
