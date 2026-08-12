# Module Specification — Sales & Invoices

> **Status:** 🟢 Approved
> **Module:** Sales & Invoices
> **Slice:** V1 — this document scopes only Sprint 10's minimal first cut, not the full V1 shape (§1)
> **Version:** 0.1.0
> **Last updated:** 2026-08-12
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 10](../../17-sprints/sprint-10.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

Lets a Cashier see the sales this device has completed. [dependency-graph.md](../../16-milestones/dependency-graph.md)
already places "POS core loop → Sales & Invoices → Receipt" as the next genuinely sequential step
once the till screen exists (Sprint 09) — this document is that next step's minimal cut, triggered
directly by the founder's own first hands-on test of the till screen surfacing the gap immediately
("it works fine, but no sell history").

**Deliberately narrow scope, found while writing this spec:** the full V1 shape of this module —
GST-compliant invoice fields (FR-055/FR-056), canonical server-assigned invoice numbers at sync
(FR-058), cross-device sales visibility, and the `GET /sales*` server endpoints already documented
in [sales.md](../../11-api/endpoints/sales.md) — all depend on modules that don't exist yet (tax,
the sync engine, device registration). This sprint builds only: a list of completed sales **this
device itself created**, read straight from the local Drift tables Sprint 09's till screen already
writes, and a detail view of one sale's line items. No network call, no new local table, no write
path — a read-only view over data that already exists on-device.

## 2. Business rules

- A sale, once completed, is immutable — already true by construction (no update/delete code path
  exists anywhere in the app for `sales`/`sale_line_items`/`sale_payments`), which is how
  [FR-053](../../03-functional-requirements/functional-requirements.md) is satisfied this sprint:
  not by an enforced constraint, but by the simple fact that nothing has ever been built that could
  violate it.
- The list shows only sales with `status = 'completed'` (the only status the till screen ever
  writes — Sprint 09) ordered most-recent-first by `completed_at`.
- A sale's line items are shown by joining against the local `products` cache for display names;
  if a product is no longer in the local cache (never possible yet, since nothing deletes products,
  but stated for when it becomes possible), the line falls back to showing its raw `product_id`
  rather than failing the whole screen.

## 3. Database tables and relationships

No new tables. Reads `sales`, `sale_line_items` (already built, Sprint 03/09) and `products`
(Sprint 03/07) from [schema-local.md](../../07-database/schema-local.md) — this module owns no
local table of its own, unlike every module before it in this project.

Server-side (`schema-server.md` Context 5) is unchanged and untouched this sprint — see §4.

## 4. API contract

| Method & path | Status |
| --- | --- |
| `GET /sales/{id}`, `GET /sales`, `GET /sales/lookup` | **Already documented** in [sales.md](../../11-api/endpoints/sales.md), **not implemented, and not needed this sprint** — this sprint's list/detail screens read only local data (§3), since nothing has synced to the server from the mobile device yet (no sync engine — backlog.md item 9). These endpoints remain server-side infrastructure for a future cross-device/server-backed sales history, not this sprint's concern. |

**Mobile-only this sprint:** `apps/mobile/lib/features/sales_history/` — two new read methods on
`SaleRepository` (`listCompletedSales()`, `getSaleDetail(id)`), no new repository interface, no
network client.

## 5. Validation rules (client and server)

None — this is a read-only feature with no user input beyond navigation (tap a list row).

## 6. Error handling and user-facing messages

An empty list renders "No sales yet" rather than an error. A detail lookup for an `id` that
doesn't exist locally (not reachable through normal navigation, since the list only links to sales
it just displayed) renders a generic "Sale not found" state rather than crashing.

## 7. Offline behaviour

Fully offline — this is the only mode that exists this sprint. The list and detail screens read
exclusively from the local Drift database; there is no server round-trip to fail or wait on.

## 8. Realtime behaviour

None. A single device's own local list has nothing to subscribe to.

## 9. UI specification

`/sales-history` and `/sales-history/:id` per
[route-map.md](../../09-navigation/route-map.md) (both routes already existed in the map, unbuilt
until now) — `apps/mobile/lib/features/sales_history/` per
[mobile-structure.md](../../08-folder-structure/mobile-structure.md)'s existing module-to-folder
mapping. Reached via a new AppBar action on the till screen (`/pos`) — the natural place a Cashier
looks right after completing sales — rather than a route-map-implied bottom-nav tab, since no shell
exists yet (same reasoning `/catalogue/add`'s FAB and `/pos`'s own home-screen button already
established in Sprints 07 and 09).

**Permission target, not enforced:** route-map.md scopes the full browsable `/sales-history` list
to Manager+ and the individual `/sales-history/:id` detail to Cashier+. Roles & Permissions
(module registry) is still entirely unbuilt — no screen in this app enforces any permission yet,
the same standing gap every other screen already has. Named here, not newly introduced.

## 10. Test plan

**Sprint 10 scope:**
- Unit tests: `listCompletedSales()` returns completed sales ordered most-recent-first; a sale with
  multiple line items returns all of them in `getSaleDetail()`; a line item whose product is missing
  from the local cache falls back to showing `product_id` rather than throwing.
- Widget tests: an empty list renders "No sales yet"; a populated list renders each sale's invoice
  number/total/timestamp and tapping one navigates to its detail; the detail screen renders line
  items and the grand total.

**Explicitly deferred:** everything in §1's "deliberately narrow scope" paragraph — GST invoice
fields, canonical invoice numbers, cross-device sales visibility, the `GET /sales*` server
endpoints, permission enforcement, receipt printing/sharing (a separate module, Receipt & Printing).

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [FR-053](../../03-functional-requirements/functional-requirements.md) (no operation can modify a completed sale) | §2 | Met — by construction, no write path exists |
| [FR-054](../../03-functional-requirements/functional-requirements.md) (a correction is a new record referencing the original) | — | **Not met** — no correction/void flow exists yet, nor a requirement to build one this sprint |
| [FR-055](../../03-functional-requirements/functional-requirements.md)–[FR-056](../../03-functional-requirements/functional-requirements.md) (GST invoice fields, Bill of Supply) | — | **Not met** — tax module doesn't exist (M1/M2 scope) |
| [FR-057](../../03-functional-requirements/functional-requirements.md) (provisional invoice number generated offline) | — | Already met, Sprint 09 — this sprint only displays it |
| [FR-058](../../03-functional-requirements/functional-requirements.md) (provisional number preserved permanently, canonical attached at sync) | — | **Not met** — no sync engine exists yet (backlog.md item 9) |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-12 | First version — written to drive Sprint 10's minimal local-only sales list/detail, prompted directly by the founder's first hands-on test of the till screen. Scope deliberately narrow: local read only, no server endpoints, no tax/canonical-numbering/permission enforcement. |
