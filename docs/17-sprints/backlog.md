# Backlog

> **Status:** 🔵 In review
> **Phase:** 17 — Sprint Planning
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
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
| 6 | Till screen: manual product add to cart (no scanning yet), cash payment only, `POST /sales` with server-side recompute | 5 | 3 |
| 7 | Stock ledger: `opening` movement on product creation, `sale` movement on sale completion (server-side, in the same transaction as the sale, per [inventory.md](../11-api/endpoints/inventory.md)) | 6 | 1.5 |
| 8 | Audit log: one entry per completed sale, per [DR-025](../03-functional-requirements/business-rules.md) | 6 | 1 |
| 9 | Sync engine: `POST /sync/push` for `product.create`/`sale.create`, `GET /sync/pull` for `products` — the minimal slice of [sync-api.md](../11-api/sync-api.md), not the full 5-entity-type pull | 5, 6 | 3 |
| 10 | Bluetooth ESC/POS receipt print (58 mm), against [receipt-design.md](../10-design-system/receipt-design.md)'s worked example | 6 | 2 |
| 11 | End-to-end proof: sign in, add a product, complete a sale in airplane mode, reconnect, watch it sync, print the receipt — [milestones.md — M0](../16-milestones/milestones.md#m0--walking-skeleton)'s exact exit criterion, executed and evidenced | 1–10 | 1 |

**Total: 18.5 person-days** — inside [roadmap.md](../16-milestones/roadmap.md)'s 15–20 person-day
estimate for M0, confirming that estimate held up under actual decomposition rather than needing
revision the moment real planning touched it.

## 2. M1–M4 — module grain only, decomposed when reached

| Milestone | Modules (decomposition pending) |
| --- | --- |
| M1 | Categories, Units, full barcode/SKU search, full stock-movement types, Roles & Permissions enforcement |
| M2 | Discount, tax computation, split payment, hold/resume, Trading Day |
| M3 | Customers, Returns & Refund, conflict-resolution field-merge |
| M4 | Reports (4), Settings, release-readiness closeout (printer/device testing, load test, adversarial suite in CI) |

## 3. Ordering rule, restated

Every dependency column above traces directly to
[dependency-graph.md](../16-milestones/dependency-graph.md)'s critical path — item order in this
backlog is not a separate judgment call, it is that graph read top to bottom for M0's slice
specifically.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | M0 fully decomposed into 11 estimated, dependency-ordered items totalling 18.5 person-days (within the Phase 16 estimate); M1–M4 left at module grain, decomposed when reached. |
