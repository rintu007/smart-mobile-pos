# Payment Providers — Provisional Market (India)

> **Status:** 🟡 Draft — provisional, tied to unconfirmed [OD-01](../01-vision/open-decisions.md)
> **Version:** 0.1.0
> **Last updated:** 2026-07-29
> **Owner:** Business Analyst
> **Sources checked:** 2026-07-29

Relevant to **V3** (Online Payment / QR Ordering), not V1 — V1 is cash and offline card/manual
methods only, per [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md). Recorded
now so V3 planning starts from real numbers rather than guesses made under deadline pressure.

---

## The rail: UPI

UPI (Unified Payments Interface) is the dominant digital-payment rail for small retail in India.
Bank-to-bank UPI and RuPay debit transactions carry a government-mandated **Zero MDR** — the banks
cannot charge a merchant fee for the transfer itself. This is the headline reason UPI QR codes are
ubiquitous at small Indian shops already — the "payment method" the product needs to support first
in V3 is very likely UPI QR, not card.

## The gateway layer

A payment aggregator (Razorpay, PhonePe Business, Cashfree, etc.) still charges a **platform fee**
even on nominally-free UPI, because they provide the reconciliation dashboard, webhook
infrastructure and merchant settlement — not the bank transfer itself.

| Provider class | Typical fee (2026, observed) | Notes |
| --- | --- | --- |
| UPI via aggregator | ~2% platform fee + 18% GST *on the fee* | The "Zero MDR" headline doesn't mean free to us — it means the bank leg is free, the aggregator leg is not |
| Card / other methods via aggregator | ~1.99%–3.5% + GST, varying by method and volume | Enterprise/negotiated rates available above ~₹5–10 lakh/month volume |

**These are variable, transaction-linked costs, not fixed infrastructure costs.** They belong in
the V3 pricing model as a pass-through (or a small margin on top), never folded into the flat
per-tenant hosting figure in [cost-model.md](../02-business-requirements/cost-model.md) — doing so
would either overcharge low-transaction shops or undercharge high-transaction ones.

**Source:** [UPI Transaction Charges 2026 (Razorpay)](https://razorpay.com/learn/upi-transaction-charges/) ·
[Payment Gateway Support for Small Businesses 2026 (Razorpay)](https://razorpay.com/blog/payment-gateway-support-for-small-businesses/)

## Consequence for the vision's "not a payments company" stance

[project-vision.md §6](../01-vision/project-vision.md) already commits us to integrating a licensed
gateway rather than holding funds ourselves. This research confirms that stance is also the
economically sensible one — building our own payment rail would mean taking on the RBI
payment-system-operator obligations (data localisation, licensing) described in
[regulatory-notes.md](regulatory-notes.md) for a rail (UPI) that is already free at the bank layer
via existing licensed providers. There is no case for building this ourselves.

## Open items for V3 planning

- [ ] Get current negotiated-rate quotes from at least two aggregators (Razorpay, PhonePe Business
      or Cashfree) once V3 is actually being scoped — rates above are directional/observed, not
      contractual quotes.
- [ ] Confirm settlement time (T+1, T+2, instant-settlement fee) — affects the Cash Drawer
      reconciliation story once online payments exist alongside cash.
- [ ] Confirm refund handling and fees through the chosen gateway — directly affects the Returns &
      Refund module once online payment exists.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-29 | Initial research pass, provisional on India as launch market. |
