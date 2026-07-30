# User Stories

> **Status:** 🟡 Draft — personas are provisional, pending Phase 05 validation
> **Phase:** 03 — Functional Requirements
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Product Manager
> **Approved by:** _pending_

28 stories (`US-001`–`US-028`) in persona/goal/benefit form. **Phase 05 has not yet run** — the
personas named here (Owner, Manager, Cashier, Inventory Staff) are the target-user names from the
founding brief, not yet validated against real shop interviews. Once Phase 05 produces validated
personas, this document is reconciled against them, not rewritten from scratch — the underlying
goals are unlikely to change even if the persona detail sharpens.

Each story's acceptance criteria point to the functional requirement(s) that make it true — this
document does not restate FR detail, it exists to keep the *why* in view alongside the *what*.

**Persona vs. system role — not the same thing.** [business-rules.md](business-rules.md)
(DR-019–DR-021) defines exactly three V1 **system roles**: Cashier, Manager, Owner. "Inventory
Staff" below is a **job function**, not a fourth role — in V1 that person operates under a Cashier
or Manager account (whichever permissions their shop grants them), the same way "Owner" covers
someone who is also physically working the till. A dedicated Inventory Staff role with its own
permission set is a plausible V2+ refinement once real shops show it's needed, not a V1 gap.

---

## Onboarding & Setup

**US-001.** As an **Owner**, I want to set up my shop in under 10 minutes, so that I can start
selling the same day I download the app.
*Acceptance:* FR-001–FR-006 complete within their combined 10-minute budget.

**US-002.** As an **Owner**, I want the app to ask about my tax registration status in plain
language, so that I don't need to understand GST jargon to get set up correctly.
*Acceptance:* FR-007, with a working default requiring no research to accept.

## Point of Sale

**US-003.** As a **Cashier**, I want to scan a barcode and take payment in as few taps as possible,
so that I can serve customers quickly during a rush.
*Acceptance:* FR-022, FR-024.

**US-004.** As a **Cashier**, I want to find a product by typing its name when the barcode won't
scan, so that a damaged label doesn't stop a sale.
*Acceptance:* FR-025.

**US-005.** As a **Cashier**, I want to put a sale on hold and come back to it, so that I can serve
another customer without losing the first customer's cart.
*Acceptance:* FR-026, FR-027.

**US-006.** As a **Cashier**, I want the till to keep working when the internet drops, so that I
never have to turn away a paying customer.
*Acceptance:* FR-009, FR-042, FR-059.

**US-007.** As an **Owner**, I want to know clearly if two staff members' phones both sold the last
item while offline, so that I'm not blindsided by a stock discrepancy days later.
*Acceptance:* FR-082, FR-048.

**US-008.** As a **Manager**, I want to approve unusually large discounts before they go through,
so that cashiers can't quietly give away margin.
*Acceptance:* FR-029.

## Catalogue

**US-009.** As an **Owner**, I want every product to have a category and a unit, so that my reports
make sense without me organising them by hand afterward.
*Acceptance:* FR-035, FR-037.

**US-010.** As an **Owner**, I want a starter list of products for my type of shop, so that I don't
have to type in my whole catalogue by hand on day one.
*Acceptance:* FR-039.

## Inventory

**US-011.** As an **Inventory Staff** member, I want to record why I'm adjusting stock, so that the
owner can trust the numbers later without asking me to explain every change.
*Acceptance:* FR-043.

**US-012.** As an **Owner**, I want to see which products are running low without checking each one
by hand, so that I never find out I'm out of stock from a disappointed customer.
*Acceptance:* FR-045, FR-074.

## Customers

**US-013.** As a **Cashier**, I want to attach a walk-in customer's phone number at checkout, so
that returns are easier later even without a receipt.
*Acceptance:* FR-050, FR-062.

**US-014.** As an **Owner**, I want to see a customer's purchase history, so that I have the
information I'd need to offer credit or loyalty later, even though V1 doesn't yet act on it.
*Acceptance:* FR-051.

## Sales & Invoices

**US-015.** As an **Owner**, I want every invoice to have the right GST fields automatically, so
that my business customers can claim their input tax credit without me worrying about the rules.
*Acceptance:* FR-055.

**US-016.** As an **Owner** running a Composition-scheme business, I want the app to issue the
correct kind of document automatically, so that I don't accidentally issue a document I'm not
legally permitted to issue.
*Acceptance:* FR-056.

## Receipts

**US-017.** As a **Cashier**, I want to print a receipt in one action, so that the customer has
proof of purchase before they walk away.
*Acceptance:* FR-059.

**US-018.** As a **Cashier**, I want to share a receipt digitally if the printer isn't working, so
that a broken printer never stops me finishing a sale.
*Acceptance:* FR-060, FR-061.

## Returns

**US-019.** As a **Cashier**, I want to process a return using just the customer's phone number, so
that a lost receipt doesn't turn into an argument at the counter.
*Acceptance:* FR-062.

**US-020.** As a **Manager**, I want to approve unusually large returns, so that the shop isn't
exposed to return fraud.
*Acceptance:* FR-066.

## Cash Drawer

**US-021.** As an **Owner**, I want to open the till with a starting cash amount and close it with
a physical count, so that I know exactly how much cash should be in the drawer at any point.
*Acceptance:* FR-067, FR-068, FR-069.

**US-022.** As an **Owner**, I want to be told immediately if the cash count doesn't match what the
system expects, so that a shortfall is caught the same day, not weeks later.
*Acceptance:* FR-070.

## Reports

**US-023.** As an **Owner**, I want to check today's sales and my current stock value from my
phone, with no export step, so that I always know where my business stands.
*Acceptance:* FR-071, FR-072.

**US-024.** As an **Owner**, I want to know which products barely sell, so that I can stop
reordering things that don't move.
*Acceptance:* FR-073.

## Settings

**US-025.** As an **Owner**, I want to configure my tax rate once and trust every sale afterward
uses it correctly, so that I never have to check each receipt by hand.
*Acceptance:* FR-075, FR-076.

**US-026.** As an **Owner**, I want to test my receipt printer from settings, so that I discover
it's broken before a customer is standing at the counter waiting.
*Acceptance:* FR-077.

## Offline Trust

**US-027.** As an **Owner**, I want to always know if some of my sales haven't synced yet, so that
I trust the app is actually saving my data even when I can't see the internet working.
*Acceptance:* FR-083.

**US-028.** As an **Owner** whose shop has patchy signal for days at a stretch, I want the app to
keep working the whole time, so that a bad network month doesn't have to mean a bad sales month.
*Acceptance:* FR-084.

---

## What is intentionally not covered

Not every functional requirement has a dedicated user story, and that is by design, not a gap —
per [documentation-standards.md](../00-governance/documentation-standards.md), the required
traceability is `BR → FR`, not `FR → US`. Several FRs are system/architectural constraints with no
natural persona-facing narrative (e.g. FR-011 idempotent deduplication, FR-046 ledger immutability,
FR-021 audit-log tamper-resistance) — these matter enormously but nobody experiences them as a
"want," only as their absence going wrong. The full `BR → FR` mapping, with or without a
corresponding story, is in [traceability-matrix.md](traceability-matrix.md).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial 28 user stories across 10 thematic groups, provisional pending Phase 05 persona validation. |
