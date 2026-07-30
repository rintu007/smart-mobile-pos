# Market Analysis

> **Status:** 🔵 In review — provisional, tied to unconfirmed [OD-01](../01-vision/open-decisions.md)
> **Phase:** 02 — Business Requirements
> **Version:** 0.1.0
> **Last updated:** 2026-07-29
> **Owner:** Business Analyst / Product Manager
> **Approved by:** _pending — provisional content, do not approve until OD-01 is confirmed_

Raw sourced facts live in [reference/device-landscape.md](../reference/device-landscape.md) and
[reference/competitor-teardown.md](../reference/competitor-teardown.md). This document synthesises
them into what they mean for the product.

---

## 1. Provisional market: India

Assumed per [open-decisions.md](../01-vision/open-decisions.md) OD-01 while unconfirmed. Chosen
only because it is the most common launch market for a product of exactly this shape — not because
of any founder-provided signal. **Every conclusion below is disposable if OD-01 resolves
differently.**

## 2. Business practices relevant to product design

| Observation | Source | Design consequence |
| --- | --- | --- |
| UPI QR is already the default digital payment expectation at small retail | [payment-providers.md](../reference/payment-providers.md) | V3's online-payment story should lead with UPI QR, not card |
| A large share of small retailers likely fall under GST Composition Scheme or below the registration threshold | [regulatory-notes.md](../reference/regulatory-notes.md) | Tax/invoice setup cannot assume every shop is a full-GST "tax invoice" issuer — Store Setup must ask, with a sane default |
| Smartphone retail itself is offline-dominant (>56% of sales) | [device-landscape.md](../reference/device-landscape.md) | "Mobile Shop" (already a named target vertical) is a plausible early pilot channel — the shop selling the phones is also a shop that needs a POS |
| Android dominates (~92% share); budget 5G devices in the ₹13,000–25,000 band are the realistic device in a cashier's hand | [device-landscape.md](../reference/device-landscape.md) | Confirms Android-first as matching the market, not just a cost decision; sets the reference low-end device target for Phase 14 |
| Mobile networks, not fixed broadband, are the primary connectivity path | [device-landscape.md](../reference/device-landscape.md) | Intermittent/flaky connectivity is the *normal* case to design and test against, not a rare edge case |

## 3. Competitive landscape summary

Full teardown in [reference/competitor-teardown.md](../reference/competitor-teardown.md). The
short version: no existing competitor combines true offline-first architecture, POS-counter speed,
GST compliance, and mobile-native design in one product. Loyverse has the polish and free tier;
Vyapar has the compliance trust; neither has the other's strength plus true offline guarantees.
This gap is the product's positioning — not a single feature, the combination.

## 4. Willingness to pay — currently unknown

This is [assumption A-03](../01-vision/risks-constraints-assumptions.md) and remains **unvalidated
until pilot interviews happen**. Observed competitor price points (Loyverse $29/month paid tier,
Vyapar ~₹1,999–6,800/year, Zoho POS ~$9/5 users/month, Marg ERP one-time ₹8,100–25,200) establish a
*market band*, not a validated willingness-to-pay figure for our specific product. Used as an input
to [pricing-strategy.md](pricing-strategy.md), explicitly flagged there as directional.

## 5. What is still missing

This document is desk research, not primary research. It cannot replace:

- Direct interviews with owners of the target verticals (grocery, general retail, stationery,
  mobile shop, etc.) — required before [05-personas](../05-personas/) can claim its personas are
  validated, not invented.
- A real device survey of pilot shop staff (assumption A-01).
- Confirmation of the launch market itself (OD-01) — the one gap that invalidates everything above
  if wrong.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-29 | Initial draft, desk research only, provisional on India as launch market. |
