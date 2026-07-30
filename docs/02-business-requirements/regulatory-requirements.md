# Regulatory Requirements

> **Status:** 🔵 In review — provisional, tied to unconfirmed [OD-01](../01-vision/open-decisions.md), **not yet practitioner-reviewed**
> **Phase:** 02 — Business Requirements
> **Version:** 0.1.0
> **Last updated:** 2026-07-29
> **Owner:** Business Analyst
> **Approved by:** _pending — provisional content, do not approve until OD-01 is confirmed, and not
> before a qualified GST practitioner reviews it_

Raw sourced research is in [reference/regulatory-notes.md](../reference/regulatory-notes.md). This
document converts that research into numbered requirements that Phase 03 can trace functional
requirements against, and that Phase 07 must satisfy in the schema.

**This document is not legal advice.** It is engineering-grade research sufficient to design
against. A qualified GST practitioner must review the actual invoice/receipt template and tax
engine behaviour before any compliance claim is made to a customer — recorded as a blocking item
in [reference/regulatory-notes.md](../reference/regulatory-notes.md#open-items-for-phase-02-proper--phase-07).

---

## RR-001 · Tax registration status is per-shop, not assumed

**Requirement.** The system must ask, during Store Setup, whether the business is GST-registered
(standard regime), Composition-scheme registered, or unregistered/below threshold — with a sane
default rather than a forced technical question.

**Rationale.** A meaningful share of target shops fall under Composition Scheme or below the
registration threshold; these issue a Bill of Supply, not a tax invoice, and cannot show an
input-credit tax breakup. Defaulting to "full GST tax invoice" would produce a document some shops
are legally not permitted to issue.

**Source.** [regulatory-notes.md — Composition Scheme](../reference/regulatory-notes.md#gst-registration-threshold-and-the-composition-scheme)

**Priority.** Must have — V1.

---

## RR-002 · Invoice numbering is sequential and gapless per financial year, per registration

**Requirement.** Every tax invoice issued by a GST-registered shop must carry a number that is
unique and sequential within its financial year, with no gaps, maximum 16 characters, using only
letters, digits, hyphens and slashes.

**Rationale.** Rule 46 mandates this; ITC rejection and penalties up to ₹25,000 follow non-sequential
numbering.

**Architectural tension — flagged, not resolved here.** This collides directly with offline,
multi-device operation. Resolving it is a Phase 07/13 schema and sync design problem (provisional
invoice number → mapped, never renumbered, per the [glossary](../GLOSSARY.md#sales)), tracked as an
open item in the [ADR backlog](../adr/README.md).

**Source.** [regulatory-notes.md — the offline-numbering collision](../reference/regulatory-notes.md#the-offline-numbering-collision--this-is-the-one-that-matters-architecturally)

**Priority.** Must have — V1 (registered-shop path). The resolution mechanism is architecturally
required before Phase 07 exits.

---

## RR-003 · Tax invoice mandatory fields

**Requirement.** For GST-registered (standard regime) shops, every invoice must include: supplier
GSTIN and legal name, sequential invoice number, invoice date, HSN/SAC code per line item, taxable
value and tax breakup per line (CGST/SGST or IGST), and buyer GSTIN when the buyer is a registered
business.

**Rationale.** Rule 46. Missing fields are the leading cause of ITC rejection for the buyer, which
makes the receipt commercially unusable to any B2B customer even where it is not itself illegal.

**Source.** [regulatory-notes.md — GST invoice mandatory fields](../reference/regulatory-notes.md#gst-invoice--mandatory-fields)

**Priority.** Must have — V1.

---

## RR-004 · Tax is computed and rounded per line item

**Requirement.** Tax must be calculated per line item, not once on the invoice total. The rounding
rule must be explicit, configurable, and applied consistently.

**Rationale.** "Rounding tax on the total instead of per line item" is cited as a common compliance
failure, and inconsistent rounding is independently a source of reconciliation disputes regardless
of tax law — see [project-vision.md §9](../01-vision/project-vision.md), money as integer minor
units.

**Source.** [regulatory-notes.md — GST invoice mandatory fields](../reference/regulatory-notes.md#gst-invoice--mandatory-fields)

**Priority.** Must have — V1.

---

## RR-005 · Dynamic QR code on B2C invoices — explicitly out of scope for V1

**Requirement.** No requirement placed on the product. Documented as a deliberate non-goal.

**Rationale.** Mandatory only above ₹500 crore aggregate turnover — several orders of magnitude
above any V1 target shop.

**Source.** [regulatory-notes.md — Dynamic QR code](../reference/regulatory-notes.md#dynamic-qr-code-on-b2c-invoices)

**Priority.** Won't have — V1. Revisit only if the product ever targets large retail chains
(explicitly out of current scope per [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)).

---

## RR-006 · Government e-invoicing (IRP submission) — explicitly out of scope for V1

**Requirement.** No requirement placed on the product for V1.

**Rationale.** Mandatory only above ₹5 crore AATO and only for B2B invoices — not the target
segment's typical profile.

**Source.** [regulatory-notes.md — E-invoicing](../reference/regulatory-notes.md#e-invoicing-government-irp-submission)

**Priority.** Won't have — V1. Worth a documented non-goal in Phase 06 workflows so it is a
deliberate choice, not a silent gap discovered by a growing customer.

---

## RR-007 · Payment data handling defers to the licensed gateway

**Requirement.** The product must not itself store or process raw payment instrument data (card
numbers, UPI credentials). Payment data localisation and payment-system-operator obligations belong
to the licensed gateway we integrate, consistent with
[project-vision.md §6](../01-vision/project-vision.md) — "not a payments company."

**Rationale.** RBI's payment-data-localisation directive addresses payment system operators, a
category we are deliberately not. Building our own payment rail would mean taking on that
regulatory category for no benefit, since UPI is already free at the bank layer via existing
licensed providers.

**Source.** [regulatory-notes.md — Payment data localisation](../reference/regulatory-notes.md#payment-data-localisation-rbi) ·
[payment-providers.md](../reference/payment-providers.md)

**Priority.** Must have — architectural constraint, applies from V3 (first module that touches
payment data) but stated now so Phase 12 designs against it from the start.

---

## RR-008 · Default database region

**Requirement.** The production database region should default to an India region regardless of
the narrow legal scope of RR-007, to minimise latency for the actual user base and avoid ambiguity
about borderline "payment-adjacent" fields (e.g. stored payment reference IDs).

**Rationale.** Not strictly mandated for general business data, but removes a category of risk at
near-zero cost, and improves the actual product experience (latency) at the same time.

**Source.** [regulatory-notes.md — Payment data localisation](../reference/regulatory-notes.md#payment-data-localisation-rbi)

**Priority.** Should have — decided formally in Phase 12, not architecturally blocking before then.

---

## Open items before this document can be finalised (blocks 🟢 approval)

- [ ] Confirm invoice/record retention period under Indian tax law with a primary source.
- [ ] Confirm Bill of Supply mandatory-field set (Composition scheme) distinct from Rule 46.
- [ ] Qualified GST practitioner review of the actual invoice and receipt template, once designed
      in Phase 10.
- [ ] **Confirm OD-01.** If the launch market is not India, this entire document is replaced.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-29 | Initial draft, 8 requirements, provisional on India as launch market. |
