# Pricing Strategy

> **Status:** 🟡 Draft — recommendation pending pilot willingness-to-pay validation ([A-03](../01-vision/risks-constraints-assumptions.md))
> **Phase:** 02 — Business Requirements
> **Version:** 0.1.0
> **Last updated:** 2026-07-29
> **Owner:** Product Manager / CTO
> **Approved by:** _pending_

Builds on [cost-model.md](cost-model.md) and [competitor-analysis.md](competitor-analysis.md), and
implements the direction already set in [project-vision.md §11](../01-vision/project-vision.md).

---

## 1. The headline finding: infrastructure cost is not the pricing constraint

[cost-model.md §3](cost-model.md) shows per-shop infrastructure cost falls from ~$2.33/month at
pilot scale (20 shops) to ~$0.04/month at 2,000 shops. Even at a conservative 15% free-to-paid
conversion and 1,000 total tenants, total infrastructure cost is roughly **$60/month against a
150-paid-shop revenue base** — infrastructure cost is a rounding error against any subscription
price in the competitive band identified in [competitor-analysis.md](competitor-analysis.md).

**This means pricing is a market-positioning decision, not a cost-recovery calculation.** The
question is not "what do we need to charge to break even on hosting" — that bar is trivially
cleared — it is "what does the target shop perceive as worth paying, relative to Vyapar, Loyverse,
and doing nothing." That question needs pilot interviews, not arithmetic.

## 2. Structure — confirmed from Phase 01 direction

Per [project-vision.md §11](../01-vision/project-vision.md), already decided:

- **Free tier:** one outlet, one user, capped monthly transactions. Must be genuinely usable — a
  crippled free tier converts nobody, and is also our primary distribution channel.
- **Paid tier:** per outlet per month. Multiple users, roles, unlimited transactions, full reports.
- **Never charged for:** offline capability, or access to the business's own data.

## 3. Free tier cap — recommendation

**Recommendation: cap the free tier at 300 sales transactions/month, not at a feature ceiling.**

This number is chosen deliberately against our own [success-metrics.md](../01-vision/success-metrics.md)
North Star: "Weekly Transacting Shops" is defined as 20+ sales in 7 days, roughly 85/month. Setting
the free cap at 300/month means a shop can comfortably clear our own definition of "genuinely
using the product" *while still on the free tier* — the free tier must be generous enough to prove
retention, not just generous enough to look generous. The upgrade trigger is a shop that has grown
past roughly 10 sales/day, at which point ₹299/month is a rounding error against what they are
now making.

Feature-gating the free tier (rather than transaction-gating) was considered and rejected: it
punishes exactly the shop we want to prove value to first, and it is easy to leave the free tier
crippled in ways that quietly damage trust — the founding vision explicitly warns against this.

## 4. Paid tier price point — recommendation, not yet validated

**Recommendation: ₹299/month per outlet, or ₹2,999/year (a ~17% discount, roughly two months free).**

Positioned against the competitor band from [competitor-analysis.md](competitor-analysis.md):

| Competitor | Approximate monthly equivalent |
| --- | --- |
| Vyapar | ~₹166–₹566/month (depending on tier, annual-only billing) |
| Zoho POS | ~$9/5 users/month ≈ ₹150/user/month at typical FX, suite-dependent |
| Loyverse paid tier | $29/month ≈ ₹2,400/month — priced for a different (Western) purchasing-power market, not a direct comparison |
| Marg ERP | One-time ₹8,100–25,200 + ~₹3,500/year AMC — different pricing shape entirely |

₹299/month sits inside the Vyapar band — the actual competitor a target shop is choosing against —
while being justified by more than accounting compliance: true offline guarantee, POS-speed
counter workflow, and mobile-native design, per the positioning gap identified in
[competitor-analysis.md](competitor-analysis.md#requirements-this-analysis-feeds-forward).

**This is a starting hypothesis, not a locked price.** [A-03](../01-vision/risks-constraints-assumptions.md)
(willingness to pay) is unvalidated. The pilot plan in Phase 16 should test price sensitivity
directly — willingness-to-pay interviews, not just this desk-research comparison.

## 5. Conversion rate target and margin check

**Target: 15% free-to-paid conversion by month 6** — a conservative, industry-typical benchmark for
a genuinely useful free tier, not derived from our own data (none exists yet). Tracked against
actual results in [success-metrics.md §5](../01-vision/success-metrics.md).

At this target, and using the worked example in [cost-model.md §3](cost-model.md):

| | Value |
| --- | --- |
| Total tenants (pilot → early growth) | 1,000 |
| Paid tenants (15%) | 150 |
| Monthly revenue at ₹299/outlet | ₹44,850 (≈ $525) |
| Total infrastructure cost at 1,000 tenants | ≈ $60.60/month |
| **Gross margin on infrastructure alone** | **>98%** |

The real cost floor this margin has to cover is not infrastructure — it's support, payment
processing fees (V3), and eventually people. Those are out of scope for this infrastructure-focused
model but the margin headroom here is large enough that infrastructure cost should never be the
reason a pricing decision goes one way or another.

## 6. What must happen before this is a real pricing decision

- [ ] Willingness-to-pay interviews with pilot shop owners (A-03) — this document is desk research,
      not customer validation.
- [ ] Confirm [OD-01](../01-vision/open-decisions.md) — currency, purchasing power and competitor
      set all change if the launch market changes.
- [ ] Decide whether annual billing is offered at launch or added later — affects cash flow and
      churn measurement differently.
- [ ] Set the actual conversion-rate target as a tracked metric once real signup data exists,
      replacing the 15% industry-benchmark placeholder.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-29 | Initial pricing recommendation: ₹299/month per outlet, 300-transaction free cap, 15% conversion target. All pending pilot validation. |
