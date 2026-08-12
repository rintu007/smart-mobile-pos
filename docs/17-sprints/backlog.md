# Backlog

> **Status:** 🔵 In review
> **Phase:** 17 — Sprint Planning
> **Version:** 0.9.0
> **Last updated:** 2026-08-13
> **Owner:** Product Manager / CTO
> **Approved by:** _pending_

Ordered, estimated, with dependencies. **M0 (Walking Skeleton) is decomposed in full, item by
item, because it is the next thing to actually execute.** M1–M4 are listed at module grain only —
per this documentation set's standing practice of not over-planning work several milestones away
(the same reasoning [roadmap.md §5](../16-milestones/roadmap.md#5-v2v4--ordering-confirmed-not-yet-effort-estimated)
already applied to V2–V4), each is decomposed to this level of detail only once M0's actual
sprint-01.md-style planning reaches it.

---

## 1. M0 — Walking Skeleton, fully decomposed

| # | Item | Depends on | Estimate (person-days) |
| --- | --- | --- | --- |
| 1 | Repository scaffold live: [monorepo-layout.md](../08-folder-structure/monorepo-layout.md)'s tree, branch protection, CI (`pr.yml`) green on an empty commit | — | 1.5 |
| 2 | Supabase project provisioned (dev environment); Auth wired with the Custom Access Token Hook injecting `tenant_id` | 1 | 1.5 |
| 3 | `tenants`/`stores` minimal write path — a signup creates one tenant and one store, per [ADR-0003](../adr/ADR-0003-multi-outlet-modelled-from-day-one.md) | 2 | 1 |
| 4 | Local Drift DB scaffold: `outbound_queue`, minimal `products`/`sales`/`stock_movements` tables per [schema-local.md](../07-database/schema-local.md) | 1 | 1.5 |
| 5 | `POST /products` (minimal: name, price only — no barcode/category yet) + local write path enqueuing to `outbound_queue` | 2, 4 | 1.5 |
| 6 | Till screen: manual product add to cart (no scanning yet), cash payment only, `POST /sales` with server-side recompute | 5, 13 | 3 |
| 7 | Stock ledger: `opening` movement on product creation, `sale` movement on sale completion (server-side, in the same transaction as the sale, per [inventory.md](../11-api/endpoints/inventory.md)) — done, [Sprint 11](sprint-11.md) | 6 | 1.5 |
| 8 | Audit log: one entry per completed sale, per [DR-025](../03-functional-requirements/business-rules.md) — done, [Sprint 12](sprint-12.md) | 6 | 1 |
| 9 | Sync engine: `POST /sync/push` for `product.create`/`sale.create`, `GET /sync/pull` for `products` — the minimal slice of [sync-api.md](../11-api/sync-api.md), not the full 5-entity-type pull — done, backend [Sprint 13](sprint-13.md) / mobile [Sprint 14](sprint-14.md) | 5, 6 | 3 |
| 10 | Bluetooth ESC/POS receipt print (58 mm), against [receipt-design.md](../10-design-system/receipt-design.md)'s worked example — software done, [Sprint 15](sprint-15.md); physical-printer verification (MTS-01) is a founder action, pending real hardware | 6 | 2 |
| 11 | End-to-end proof: sign in, add a product, complete a sale in airplane mode, reconnect, watch it sync, print the receipt — [milestones.md — M0](../16-milestones/milestones.md#m0--walking-skeleton)'s exact exit criterion, executed and evidenced | 1–10, 12 | 1 |
| 12 | Mobile sign-in screen (`/auth/login`): direct client call to Supabase Auth per [authentication/specification.md §9](../modules/authentication/specification.md#9-ui-specification), session persisted on-device — the first real Flutter screen and the actual prerequisite for item 11's "sign in" step, which this list never decomposed as its own item until Sprint 06 planning caught the gap | 2, 3 | 1.5 |
| 13 | Store context: `GET /api/v1/stores` + a mobile fetch-and-cache step after sign-in — a real prerequisite for item 6 (the till screen cannot create a sale without knowing its own `store_id`, and nothing before this item gave the device one) that item 6's own decomposition never accounted for, found during Sprint 08 planning | 2, 12 | 1 |

**Total: 21 person-days** (20 across items 1–12, plus item 13's 1, added 2026-08-02 — see Change
Log) — now past the top edge of [roadmap.md](../16-milestones/roadmap.md)'s 15–20 person-day
estimate for M0. Both real omissions found so far (item 12, item 13) surfaced only once mobile UI
work actually started reaching for something the backend-first sprints never had to think about —
worth naming as a pattern, not just two isolated misses: **a backlog decomposed before any UI
existed is at real risk of under-counting exactly the connective-tissue work UI needs** (session
persistence, device-to-store binding) that a backend-only walking skeleton never surfaces. Reported
honestly rather than absorbed into an existing item's estimate, same reasoning item 12's correction
already established.

## 2. M1–M4 — module grain only, decomposed when reached

| Milestone | Modules (decomposition pending) |
| --- | --- |
| M1 | Categories, Units, full barcode/SKU search, full stock-movement types, Roles & Permissions enforcement, **Sales & Invoices (full V1 shape — GST invoice fields, canonical numbering at sync, `GET /sales*` server endpoints, permission enforcement)** |
| M2 | Discount, tax computation, split payment, hold/resume, Trading Day |
| M3 | Customers, Returns & Refund, conflict-resolution field-merge |
| M4 | Reports (4), Settings, release-readiness closeout (printer/device testing, load test, adversarial suite in CI) |

**Correction, found 2026-08-12:** this table never listed Sales & Invoices at all, despite
[dependency-graph.md](../16-milestones/dependency-graph.md) already fixing it as the module
immediately after "POS core loop" on the project's longest sequential dependency chain — a real
omission, not a deliberate exclusion. Added to M1 above (its full V1 shape genuinely needs Roles &
Permissions and the sync engine, both M1/later). **A minimal slice was pulled forward into Sprint
10**, ahead of M1, at the founder's direct request the moment real device testing surfaced the
gap — a local-only, this-device's-own-sales list/detail view needing none of M1's actual
prerequisites. See [sales-invoices/specification.md](../modules/sales-invoices/specification.md)
§1 for exactly what that minimal slice is and isn't.

## 3. Ordering rule, restated

Every dependency column above traces directly to
[dependency-graph.md](../16-milestones/dependency-graph.md)'s critical path — item order in this
backlog is not a separate judgment call, it is that graph read top to bottom for M0's slice
specifically.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | M0 fully decomposed into 11 estimated, dependency-ordered items totalling 18.5 person-days (within the Phase 16 estimate); M1–M4 left at module grain, decomposed when reached. |
| 0.2.0 | 2026-08-02 | Sprint 06 planning found a real gap: this decomposition never listed a mobile sign-in screen as its own item, despite item 11's E2E proof requiring "sign in" as its first step and despite [authentication/specification.md §9](../modules/authentication/specification.md#9-ui-specification) already anticipating the `/auth/login` route. Added item 12 (depends on 2, 3; 1.5 person-days) and updated item 11's dependency list to include it, rather than silently folding the work into an existing item's estimate. Total revised to 20 person-days. |
| 0.3.0 | 2026-08-02 | Sprint 08 planning found another real gap of the same shape: item 6 (the till screen) cannot create a sale without knowing its own `store_id`, and nothing in this decomposition ever gave the device one. Added item 13 (depends on 2, 12; 1 person-day) and updated item 6's dependency list. Total revised to 21 person-days, now past roadmap.md's 15–20 estimate — named as a pattern (backend-first decomposition under-counts UI connective-tissue work), not just a second isolated miss. |
| 0.4.0 | 2026-08-12 | §2 correction: Sales & Invoices was never listed at M1–M4 module grain at all, despite dependency-graph.md already fixing its position right after POS core loop. Added to M1. A minimal local-only slice pulled forward into Sprint 10, ahead of M1, at the founder's direct request after real device testing surfaced the gap immediately. |
| 0.5.0 | 2026-08-13 | Item 7 (stock ledger) done — [Sprint 11](sprint-11.md): `opening`/`sale` movements written server-side, each in the same transaction as its triggering row. M0 now has items 8–11 remaining. |
| 0.6.0 | 2026-08-13 | Item 8 (audit log) done — [Sprint 12](sprint-12.md): one `sale.completed` entry written server-side, in the same transaction as the sale. M0 now has items 9–11 remaining. |
| 0.7.0 | 2026-08-13 | Item 9 (sync engine) backend half done — [Sprint 13](sprint-13.md): `POST /sync/push`/`GET /sync/pull` built and live-verified. Mobile trigger/outbound-queue drain remains, tracked as the concrete next sprint. |
| 0.8.0 | 2026-08-13 | Item 9 done in full — [Sprint 14](sprint-14.md): mobile trigger built, `outbound_queue` now actually drains. M0 now has items 10–11 remaining. |
| 0.9.0 | 2026-08-13 | Item 10 software done — [Sprint 15](sprint-15.md): receipt formatting, ESC/POS encoding, and Bluetooth transport all built and unit-tested. Physical-printer verification (MTS-01) named as a founder action, not run — no hardware available. M0 now has only item 11 remaining. |
