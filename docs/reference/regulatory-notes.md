# Regulatory Notes — Provisional Market (India)

> **Status:** 🟡 Draft — provisional, tied to unconfirmed [OD-01](../01-vision/open-decisions.md)
> **Version:** 0.1.0
> **Last updated:** 2026-07-29
> **Owner:** Business Analyst
> **Sources checked:** 2026-07-29

**Everything in this document is provisional.** It is researched against India because that is the
placeholder market recorded in [open-decisions.md](../01-vision/open-decisions.md) while OD-01
remains unconfirmed by the founder. If the real launch market differs, this entire document is
replaced, not patched — tax and receipt law do not transfer between jurisdictions.

This is not legal advice and is not a substitute for a qualified GST practitioner's review before
launch. It is sufficient to design against; it is not sufficient to ship compliance claims on.

---

## GST invoice — mandatory fields

Under GST Rule 46, a valid tax invoice requires (non-exhaustive, the fields that constrain our
schema and receipt layout):

| Field | Design consequence |
| --- | --- |
| Supplier's GSTIN and legal name | Store Setup module must capture and validate GSTIN format |
| Invoice number — unique per financial year, sequential, **no gaps**, max 16 characters, letters/numbers/hyphen/slash only | Directly collides with offline operation — see below |
| Invoice date | Trivial |
| HSN/SAC code per line item | Product module needs an HSN/SAC field, not just a free-text category |
| Taxable value and tax rate per line, tax breakup (CGST/SGST or IGST) | Tax engine must support per-line rates, not just a single shop-wide rate |
| Place of supply | Relevant mainly for interstate — low priority for a single-outlet local shop but the field must exist |
| Buyer's GSTIN (B2B only) | Optional for consumer retail sales; required if the customer is a registered business claiming input credit |

**Common compliance failures** cited in current guidance: wrong buyer GSTIN, missing HSN/SAC,
incorrect place of supply, **non-sequential invoice numbers**, missing reverse-charge notation,
rounding tax on the invoice total instead of per line item. The last two are direct inputs to
[money-and-tax.md](../07-database/README.md) in Phase 07: **tax must round per line, not once at
the end**, and rounding rule must be explicit and consistent.

Penalty for incorrect invoice details: up to ₹25,000 under Section 122, and denial of input tax
credit to the buyer — the latter is the sharper business risk, since it makes our invoice
*unusable* to a business customer, not merely non-compliant.

**Sources:** [GST Invoice Format 2026 — 16 Mandatory Fields (redpulsesoftware)](https://redpulsesoftware.in/blog/gst-invoice-format-guide-2026) ·
[GST Invoice Rules 2026 (Tax Garden)](https://taxgarden.in/blog/gst-invoice-rules-format-mandatory-fields-e-invoice-india-2026) ·
[GST Invoice Mandatory Fields (weandgst)](https://www.weandgst.in/gst-invoice-mandatory-fields-india/)

---

## The offline-numbering collision — this is the one that matters architecturally

GST law requires invoice numbers to be **sequential with no gaps** within a financial year. Our
architecture requires devices to be able to sell **with no connectivity**, potentially for days,
potentially several devices at once in the same shop.

Two devices offline at once, each locally assigning "next number," cannot both produce a
gapless global sequence — that is only knowable once both are back online. This is exactly the
problem [risk R-06](../01-vision/risks-constraints-assumptions.md#r-06--tax-and-receipt-legal-requirements-are-market-specific--priority-12-i4--l3)
and the "provisional invoice number" concept in the
[glossary](../GLOSSARY.md#sales) exist to solve, and it is a **required Phase 07 / Phase 13 design
problem**, not something this document can resolve. Recorded here so Phase 07 has the legal
constraint in front of it, not just the technical one.

**Design direction (not yet a decision):** a single device is very likely the source of truth for
numbering per store during working hours in the V1 single-outlet, single-till model, which
sidesteps the worst of the multi-device collision. Once a shop runs multiple simultaneous tills
(V4), this needs a real allocation scheme (e.g. server-issued number blocks per device, reserved
in advance during connectivity). This is flagged for the ADR still open in the
[decision backlog](../adr/README.md).

---

## Dynamic QR code on B2C invoices

Mandatory only for entities with **aggregate annual turnover above ₹500 crore** — several orders of
magnitude above any V1 target shop. **Not a V1 requirement.** Re-check if/when the product targets
larger retail chains (outside current scope).

**Source:** [QR Code on B2C Invoices (Masters India)](https://www.mastersindia.co/blog/b2c-invoices-qr-code/)

---

## E-invoicing (government IRP submission)

Mandatory only above **₹5 crore Annual Aggregate Turnover (AATO)**, and only for **B2B** invoices —
not for consumer retail (B2C) sales, which is the overwhelming majority of transactions for our
target shops. **Not a V1 requirement** for the target segment. A shop that grows past this
threshold, or that serves other registered businesses at volume, would need it — worth flagging in
Phase 06 workflows as a documented non-goal rather than a silent gap.

**Source:** [E-Invoicing Rules in India 2026 (Tally Solutions)](https://tallysolutions.com/accounting/e-invoicing-rules-in-india/)

---

## GST registration threshold and the Composition Scheme

Many of our actual target shops (single-owner, low-volume retail) may fall under the **GST
Composition Scheme** (turnover up to ₹1.5 crore for goods, ₹75 lakh in special-category states) or
below the basic GST registration threshold entirely. Composition-scheme taxpayers:

- Pay a flat rate (1% for traders/manufacturers) instead of slab-wise GST.
- File quarterly, not the 24+-filing full-compliance burden.
- **Cannot issue a tax invoice with input-credit breakup** — they issue a "Bill of Supply" instead,
  a materially different document.

**Design consequence:** the tax engine and receipt template cannot assume every shop is a
full-GST-regime "tax invoice" issuer. Store Setup must ask (with a sane default) whether the
business is Composition-scheme, standard-regime, or unregistered/below-threshold, and the
receipt/invoice template — and the fields validated — must change accordingly. This is a **V1
requirement**, not a later add-on, because getting the base case wrong for the majority of small
shops is worse than omitting a feature.

**Source:** [GST Composition Scheme 2026 (accountune)](https://accountune.com/gst-composition-scheme-2026) ·
[GST Composition Scheme: Eligibility & Rates (vakilsearch)](https://vakilsearch.com/article/gst-composition-scheme/)

---

## Payment data localisation (RBI)

RBI's Storage of Payment System Data directive requires **payment system data** (full end-to-end
transaction and payment-instruction data) to be stored **exclusively on servers in India**; if
processed abroad, it must be deleted from the foreign system within 24 hours / one business day.

**Scope note, important for our architecture:** this directive is addressed to banks, PPI issuers,
card networks and **authorised payment system operators** — categories we are explicitly not, per
[project-vision.md §6](../01-vision/project-vision.md) ("not a payments company"). We integrate a
licensed gateway (Razorpay, PhonePe, etc.); *they* carry the payment-system-operator obligation for
the payment instruction itself. Our obligation is narrower: general business/sales data does not
carry the same statutory localisation requirement as payment-instruction data, but **Supabase's
region selection should default to an India region regardless**, both because it minimises latency
for our actual users and because it removes an entire category of ambiguity about what counts as
"payment-adjacent" data in our own tables (e.g. a stored payment reference ID). This is a Phase 12
decision, not resolved here.

**Source:** [Data Localization in India Under RBI (Opsio)](https://opsiocloud.com/in/knowledge-base/data-localization-in-india-rbi/) ·
[RBI: Payments data must be stored in systems in India (Business Standard)](https://www.business-standard.com/article/economy-policy/payments-data-must-be-stored-in-systems-located-in-india-says-rbi-119062700043_1.html)

---

## Open items for Phase 02 proper / Phase 07

- [ ] Confirm invoice retention period under Indian tax law (commonly cited as multi-year; exact
      figure not verified in this pass — needed for [audit-model.md](../07-database/README.md)).
- [ ] Confirm whether a Bill of Supply (Composition scheme) has its own mandatory-field set distinct
      from Rule 46, with a primary source, before Phase 10 finalises the receipt template.
- [ ] Get a qualified GST practitioner's review of the invoice/receipt template before any
      compliance claim is made to customers. This document is engineering-grade research, not a
      legal opinion.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-29 | Initial research pass, provisional on India as launch market. |
