# Privacy

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.2.0
> **Last updated:** 2026-08-19
> **Owner:** Security Engineer / CTO
> **Approved by:** _pending_

Personal data inventory, lawful basis, retention, and deletion/export — the first phase to address
data-protection law directly. [regulatory-requirements.md](../02-business-requirements/regulatory-requirements.md)
covered tax and invoicing regulation; it did not cover personal-data-protection law, which is
squarely this phase's remit, addressed here for the first time rather than a gap in Phase 02.

---

## 1. Personal data inventory

| Data | Table | Whose data | Sensitivity |
| --- | --- | --- | --- |
| Display name | `users` | Staff (Cashier/Manager/Owner) | Low — employment-context data |
| Customer name, phone | `customers` | End customers | Low-to-moderate — direct identifier (phone) |
| Actor attribution | `audit_log` | Staff | Low — necessary for accountability, per [audit-logging.md](audit-logging.md) |
| Purchase association | `sales.customer_id` | End customers | Low — a link to what was bought, not a sensitive category (no health, financial-instrument, or biometric data anywhere in this schema, per [RR-007](../02-business-requirements/regulatory-requirements.md)'s payment-data exclusion) |

**What this product deliberately never collects**, restated because absence is a design decision,
not an oversight: raw payment instrument data (RR-007), any biometric identifier, precise
geolocation beyond what [OpenStreetMap](../01-vision/project-vision.md)-based delivery features
might add in a later phase (not yet built).

## 2. Lawful basis — provisional, tied to the same OD-01 assumption as everything else tax-adjacent

Under [OD-01](../01-vision/open-decisions.md)'s **provisional, unconfirmed** assumption of India as
the launch market, India's Digital Personal Data Protection Act, 2023 (DPDPA) is the relevant
framework. **This is stated provisionally, with the same standing caveat already attached to every
other India-specific regulatory assumption in this documentation set** — it is not legal advice, and
is pending both OD-01's confirmation and a qualified legal/privacy review, tracked as the same
cross-phase open item as the GST-practitioner review. The working lawful basis for the data in §1:
**contractual necessity** (a customer's name/phone, when captured, supports the transaction and any
return lookup they'd want) and **legitimate business interest** (staff accounts, audit attribution)
— never a data category that would require a heavier basis such as explicit consent for a special
category, since no special-category data is collected at all.

## 3. Retention

| Data | Retention |
| --- | --- |
| Customer records | Indefinite, unless a deletion request is received (§4) — a shop plausibly wants purchase-history continuity with a repeat customer for years |
| Staff accounts | Indefinite while employed; deactivated (Tier 1 soft delete) on departure, not deleted, since historical sales/audit attribution must remain resolvable to a name |
| Audit log | Indefinite, per [audit-logging.md §3](audit-logging.md#3-retention) |

## 4. Deletion — reconciling erasure rights with ledger immutability

This is the one genuine tension this document has to resolve, not merely restate:
[ADR-0009](../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md) requires
`sales`/`returns` (Tier 2) to never be deleted, for financial-record-integrity reasons — but a
privacy-law erasure request concerns the *personal data*, not the *financial fact* of the
transaction having occurred.

**Resolution:** an erasure request against a `customers` row **anonymises** it — `name` and `phone`
are overwritten with a null/redacted marker — rather than deleting the row. The row's `id` survives,
so every historical `sales.customer_id` foreign key remains valid and the sale itself, its totals,
and its tax record are untouched and still exactly as immutable as
[ADR-0009](../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md) requires —
what is erased is specifically the *identifying* data, not the *financial* record. This is the same
principle [DR-014](../03-functional-requirements/business-rules.md)-adjacent logic already applies
elsewhere in this schema (a sale outlives a deactivated customer record, per
[schema-server.md](../07-database/schema-server.md)'s `ON DELETE SET NULL` note) extended one step
further, deliberately, to satisfy an erasure request without touching ledger integrity.

**Built Sprint 46 (backlog.md, cross-cutting fix — found unbuilt during Sprint 43's OWASP checklist
review, M6):** `POST /api/v1/customers/{id}/erase`
([customers.md](../11-api/endpoints/customers.md)), Owner-only — a step stricter than `DELETE`'s
Manager+Owner gate, since erasure is a data-governance/legal action, not an ordinary back-office one.
Nulls `name`/`phone`, sets a new explicit `erased_at` marker (distinguishing genuine erasure from a
customer who simply never had a name/phone set — both nullable already at creation), and also sets
`deactivated_at` if not already set, since an erased customer has no identifying data left for any
real workflow to act on correctly. Idempotent (a second request on an already-erased customer is a
pure no-op) and verified against a real database, including that a historical sale referencing the
erased customer keeps resolving correctly afterward
(`apps/web/integration-tests/customer-erasure.test.ts`) — not merely that no error was thrown.

Staff accounts (`users`) are **not** given the same anonymisation path on request — an employee's
attribution in `audit_log` and completed `sales.created_by` is an accountability record the business
itself needs to retain (and, per §2, is justified under legitimate business interest, not consent
that could be withdrawn), matching how [ADR-0009](../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md)
already treats staff deactivation as soft-delete, not erasure.

## 5. Export

A customer's own data (their `customers` profile fields plus their `sales`/`return` history) is
fully assemblable from existing, already-designed queries — [customers.md](../11-api/endpoints/customers.md)'s
`GET /customers/{id}/purchase-history` plus the profile fields are the entire data export payload;
no new data model is needed. **The actual export endpoint/format (e.g. a JSON or CSV download) is a
Phase 18 implementation task**, not an architectural gap — the data to export and its shape are
already fully specified by Phase 11's existing endpoints.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Personal data inventory; DPDPA named as the provisional applicable framework (same caveat as all India-specific content); anonymise-not-delete resolution for customer erasure requests, reconciling ADR-0009; export shown to require no new data model. |
| 0.2.0 | 2026-08-19 | Sprint 46 — §4's anonymise-not-delete resolution, designed since this document's first version but never implemented (found Sprint 43's OWASP review, M6), built as `POST /customers/{id}/erase`, Owner-only, idempotent, verified against a real database including FK-integrity survival. |
