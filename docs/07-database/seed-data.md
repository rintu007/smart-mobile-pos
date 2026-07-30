# Seed Data — Business-Type Starter Catalogues

> **Status:** 🔵 In review
> **Phase:** 07 — Database Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** PostgreSQL Architect / Business Analyst
> **Approved by:** _pending_

Directly supports the ten-minute onboarding promise —
[FR-002](../03-functional-requirements/functional-requirements.md) (business-type defaults load
instantly, no network) and [FR-039](../03-functional-requirements/functional-requirements.md)
(starter catalogue import). This document specifies the **structure** of a business-type template
and fully works two examples; the remaining V1 verticals follow the same template as a content-
authoring task, not an architecture one.

---

## 1. Where seed data lives, and why

**Bundled as a static asset with the mobile app build, not fetched from the server at onboarding
time.** This follows directly from [FR-002](../03-functional-requirements/functional-requirements.md)'s
requirement that business-type selection works with zero network request — a server-fetched
template would violate that the instant a shop tries to onboard somewhere with no signal, which per
[project-vision.md §8](../01-vision/project-vision.md) Principle 1 is the *normal*, not exceptional,
condition to design for.

**Accepted trade-off:** updating seed content (adding a new business type, correcting a starter
product list) requires an app release, not a server-side content update. This is a deliberate
consequence of the offline-first onboarding requirement, not an oversight.

## 2. Template structure

Every business-type template provides:

| Component | Populates |
| --- | --- |
| Default `tax_mode` | `shop_settings.tax_mode` — see [RR-001](../02-business-requirements/regulatory-requirements.md); the safest universal default is `unregistered`, since assuming GST registration for a shop that isn't would produce an invalid document, while the reverse (a registered shop temporarily under-declaring) is a one-tap correction during setup |
| Default `rounding_rule` | `shop_settings.rounding_rule` — `round_half_up` universally, per [money-and-tax.md](money-and-tax.md) |
| Starter `categories` | 4–8 categories typical of the vertical |
| Starter `units` | Always includes `piece` (whole numbers only) and, where relevant, `kilogram`/`litre` (fractional-allowed) |
| Starter `products` | 5–10 illustrative products with realistic pricing, category, and unit assignment — enough to demonstrate the catalogue and complete a first sale within the 3-minute budget, not a complete real catalogue |
| Default discount/return thresholds | `shop_settings.discount_auto_approval_threshold_minor_units` / `return_auto_approval_threshold_minor_units` — set conservatively per vertical (a lower-margin grocery shop's sensible discount threshold differs from a higher-margin gift shop's) |

**Universal units**, available regardless of business type: `piece` (`allows_fractional = false`),
`kilogram` and `litre` (`allows_fractional = true`), `packet` (`allows_fractional = false`).

## 3. Worked example — Grocery / Super Shop

| Setting | Value |
| --- | --- |
| Default tax mode | `unregistered` (many small grocery shops fall below the registration threshold — [regulatory-requirements.md](../02-business-requirements/regulatory-requirements.md)) |
| Discount auto-approval threshold | ₹20 (2,000 paise) — low, reflecting thin grocery margins |
| Return auto-approval threshold | ₹200 (20,000 paise) |

**Categories:** Staples & Grains, Dairy & Eggs, Snacks & Beverages, Household Essentials, Personal
Care, Fresh Produce.

**Starter products:**

| Product | Category | Unit | Price |
| --- | --- | --- | --- |
| Rice (loose) | Staples & Grains | kilogram | ₹50.00/kg |
| Toor Dal | Staples & Grains | kilogram | ₹120.00/kg |
| Milk (500ml pouch) | Dairy & Eggs | piece | ₹28.00 |
| Eggs (pack of 6) | Dairy & Eggs | piece | ₹42.00 |
| Biscuits (family pack) | Snacks & Beverages | piece | ₹12.00 |
| Bottled water (1L) | Snacks & Beverages | piece | ₹20.00 |
| Detergent powder | Household Essentials | kilogram | ₹65.00/kg |
| Soap bar | Personal Care | piece | ₹35.00 |

## 4. Worked example — Mobile Shop / Electronics Accessories

| Setting | Value |
| --- | --- |
| Default tax mode | `standard` (electronics retail more commonly operates at a scale requiring GST registration) |
| Discount auto-approval threshold | ₹100 (10,000 paise) |
| Return auto-approval threshold | ₹1,000 (100,000 paise) — higher-value goods |

**Categories:** Phone Cases & Covers, Chargers & Cables, Screen Protectors, Earphones & Audio,
Power Banks, Repair Services.

**Starter products:**

| Product | Category | Unit | Price | HSN/SAC |
| --- | --- | --- | --- | --- |
| Silicone phone case | Phone Cases & Covers | piece | ₹199.00 | (populated per catalogue standard) |
| USB-C fast charger | Chargers & Cables | piece | ₹399.00 | |
| Tempered glass screen protector | Screen Protectors | piece | ₹99.00 | |
| Wired earphones | Earphones & Audio | piece | ₹149.00 | |
| 10,000mAh power bank | Power Banks | piece | ₹899.00 | |

This vertical demonstrates HSN/SAC being populated at seed time — since it defaults to `standard`
tax mode, [FR-033](../03-functional-requirements/functional-requirements.md)'s flagging behaviour
for a missing HSN/SAC would otherwise fire on every starter product, which is exactly the kind of
friction the ten-minute promise ([BR-001](../02-business-requirements/business-requirements.md))
exists to eliminate.

## 5. Remaining V1 verticals — same template, content not yet authored

Stationery, Hardware, Gift Shop, Toy Shop, Book Store, Fashion — each follows §2's template
identically. Authoring their specific category/product lists is a content task for Phase 18
(Implementation), not an architectural decision; flagged here so it isn't forgotten, not deferred
for lack of importance.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial template structure; Grocery and Mobile Shop worked fully; remaining verticals flagged as a content task. |
