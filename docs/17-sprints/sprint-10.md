# Sprint 10

> **Dates:** 2026-08-12 – 2026-08-12 (single-day, same pattern as Sprints 02–09)
> **Milestone:** Sales & Invoices (minimal slice, pulled forward ahead of M1 — see below)
> **Status:** Closed

## Goal

Build a local sales-history list and detail view (`/sales-history`, `/sales-history/:id`) —
prompted directly by the founder's own first hands-on test of Sprint 09's till screen on a real
device: "it works fine, but no sell history."

## Why this isn't M0 or a mechanical next backlog item

M0's own exit criterion ([milestones.md](../16-milestones/milestones.md#m0--walking-skeleton)) never
included viewing past sales — M0 resumes at item 7 (stock ledger) after this sprint. This is a
deliberate, founder-directed insertion of Sales & Invoices' minimal local slice, not a claim that
M0's own remaining items (7–11) are done or skipped. See
[backlog.md's 2026-08-12 correction](backlog.md#change-log) and
[sales-invoices/specification.md §1](../modules/sales-invoices/specification.md#1-purpose-and-business-context)
for the full reasoning — [dependency-graph.md](../16-milestones/dependency-graph.md) already fixed
Sales & Invoices as the module immediately after POS's core loop, so this isn't scope invented from
nothing; it's the next node on an already-approved critical path, reached earlier than M1's own
grouping anticipated because real usage made the need concrete today rather than later.

## Scope

| Module | Estimate (person-days) | Depends on |
| --- | --- | --- |
| Sales & Invoices (local-only list/detail, no server, no new local table) | ~1.5 | POS core loop (Sprint 09) |

Mobile only: `apps/mobile/lib/features/sales_history/` (new feature folder, already anticipated in
[mobile-structure.md's module mapping](../08-folder-structure/mobile-structure.md#5-module-to-feature-folder-mapping)).
Two new read-only methods on `SaleRepository`; no new Drift table (reads `sales`/`sale_line_items`/
`products`, all already written by Sprint 09); no network client; no backend changes.

## Capacity check

~1.5 person-days against [sprint-cadence.md](sprint-cadence.md)'s ~3.75 person-day budget — well
inside budget, the smallest sprint since Sprint 08.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: `sales-invoices/specification.md` (new), backlog.md's
      correction, module registry, implementation-log, README bumps — inside the estimate above.

## Risks

- **No new device-target risk** — same `flutter test` (repository tests against a real Drift
  database) plus widget tests (overridden providers) pattern every prior sprint has used; this
  sprint additionally has a real founder-owned device to demo against directly, a first for this
  project (every prior "live" proof used a temporary throwaway account, deleted after).
- **Scope discipline**: the temptation to also build GST fields/canonical numbers/permission
  enforcement while touching this module was named and explicitly declined — see
  `sales-invoices/specification.md §1`'s "deliberately narrow scope."

## Definition of Done

- [x] `SaleRepository.listCompletedSales()` returns this device's completed sales, most-recent-first.
- [x] `SaleRepository.getSaleDetail(id)` returns a sale's line items, with a graceful fallback if a
      referenced product is missing from the local cache.
- [x] `/sales-history` list screen and `/sales-history/:id` detail screen, reached via a new AppBar
      action on the till screen (`/pos`).
- [x] `flutter analyze` / `flutter test` clean (52 tests, up from 44).
- [x] No secret, token, or key written to logs or committed to source.
- [x] `sales-invoices/specification.md` (new), backlog.md, module registry, implementation-log, and
      READMEs updated in the same PR.
- [x] Rebuilt APK installed on the founder's own device, sales history checked against real sales
      already created there — confirmed by the founder 2026-08-13.

**Explicitly not in this sprint's DoD subset:** GST invoice fields, canonical invoice numbers,
`GET /sales*` server endpoints, permission enforcement, receipt printing/sharing, M0's own remaining
items (7–11).

## Demo script

**Mobile, local** (`flutter test`, no device needed):
1. `listCompletedSales()` returns sales ordered by `completed_at` descending.
2. `getSaleDetail(id)` returns all line items for a multi-line sale; a line whose product isn't in
   the local cache falls back to showing its raw `product_id`.
3. Widget tests: empty state renders "No sales yet"; a populated list renders invoice
   number/total/timestamp per row and navigates to detail on tap; detail renders line items and
   grand total.

**Real device** (the founder's own phone, first time this project has done this): rebuilt APK
installed over the existing one; the sales already created during the founder's first test appear
in the list with correct totals and invoice numbers.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. (One candidate worth naming regardless: this is the
first sprint whose trigger was the founder's own hands-on use of a real build, not planning-time
analysis — worth watching whether this becomes a recurring, valuable source of gaps going forward.)

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-12 | Sprint 10 planned: minimal local sales-history list/detail, pulled forward ahead of M1 at the founder's direct request after their first real-device test of the till screen surfaced the gap. New module specification written first (`sales-invoices/specification.md`); backlog.md corrected (Sales & Invoices was never listed at M1–M4 module grain at all). |
| 0.2.0 | 2026-08-12 | Sprint 10 closed: `/sales-history` and `/sales-history/:id` built, `flutter analyze`/`flutter test` clean (52/52, up from 44). PR pending; APK rebuild and reinstall on the founder's own phone tracked as the sprint's final step. |
| 0.3.0 | 2026-08-13 | Final DoD box ticked: founder confirmed the rebuilt APK's sales history matches real sales made on their own device. Sprint 10 fully done, no open items remain. |
