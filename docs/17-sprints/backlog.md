# Backlog

> **Status:** 🔵 In review
> **Phase:** 17 — Sprint Planning
> **Version:** 0.22.0
> **Last updated:** 2026-08-14
> **Owner:** Product Manager / CTO
> **Approved by:** _pending_

Ordered, estimated, with dependencies. **M0, M1, and M2 are decomposed in full, item by item, in
the order planning actually reached them; M3–M4 are still listed at module grain only** — per this
documentation set's standing practice of not over-planning work several milestones away (the same
reasoning [roadmap.md §5](../16-milestones/roadmap.md#5-v2v4--ordering-confirmed-not-yet-effort-estimated)
already applied to V2–V4), each decomposed to this level of detail only once actual sprint planning
reaches it.

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
| 11 | End-to-end proof: sign in, add a product, complete a sale in airplane mode, reconnect, watch it sync, print the receipt — [milestones.md — M0](../16-milestones/milestones.md#m0--walking-skeleton)'s exact exit criterion, executed and evidenced — **in progress, [Sprint 16](sprint-16.md)**: steps 1–7 confirmed working by the founder 2026-08-14, no bug found; step 8 (print) still blocked on physical printer hardware | 1–10, 12 | 1 |
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

## 2. M1 — fully decomposed 2026-08-14, now that M0 has reached this point

M0 closed for planning purposes on 2026-08-14 — every item except backlog item 11's physical-print
step (blocked on printer hardware the founder doesn't yet own, tracked separately in
[sprint-16.md](sprint-16.md), not blocking further work per the founder's own direction, see
[modules/README.md](../modules/README.md) Rule 2's third exception). Per this document's own
stated practice (§ intro), M1 is decomposed to item grain only now that planning has actually
reached it — M2–M4 stay at module grain below.

| # | Item | Depends on | Estimate (person-days) |
| --- | --- | --- | --- |
| 1 | `categories` table + `POST`/`GET`/`PATCH`/`DELETE /categories` (server) — [catalogue.md](../11-api/endpoints/catalogue.md), `CATEGORY_IN_USE` on delete-while-referenced | — | 1 |
| 2 | `units` table + `POST`/`GET /units` (server) — done, [Sprint 18](sprint-18.md); `PATCH`/`DELETE`, `allows_fractional` immutability (`UNIT_FRACTIONAL_FLAG_LOCKED`) deferred, same reason item 1's `PATCH`/`DELETE` are | — | 1 |
| 3 | Extend `products`: `category_id`/`unit_id` (FK, existence-validated), `sku`/`barcode`/`hsn_sac_code` (optional) — done, [Sprint 19](sprint-19.md); **all optional, not required** — see that sprint's own dated correction (products/specification.md §1) for why "required" broke on contact with real production data | 1, 2 | 1.5 |
| 4 | Mobile: categories/units local tables + CRUD screens (`/catalogue/categories`, `/catalogue/units`), `/catalogue/add` updated to require a category/unit selection — done, [Sprint 20](sprint-20.md); creation is online-only (no `category.create`/`unit.create` sync-push type exists — a named, dated deviation, not full offline CRUD) | 1, 2, 3 | 2 |
| 5 | Full barcode/SKU search: `GET /products?search=&category_id=` (server) + mobile barcode scan wired into the till's product picker — FR-034/FR-036 — done, [Sprint 21](sprint-21.md); the till's own scan/search/filter is local-only (both FRs are "Fully offline"), the server endpoint stands as its own capability, not yet consumed by any built mobile screen | 3, 4 | 2 |
| 6 | Full stock-movement types: `adjustment` movement + `reason_code`, public `POST`/`GET /stock-movements`, `GET /products/{id}/stock-balance` — done, [Sprint 22](sprint-22.md); found while writing the spec: `POST /stock-movements` doesn't accept `movement_type: 'opening'` after all, since every product already gets one automatically at creation (a named, dated deviation from inventory.md's original documented contract, not an oversight) | 3 | 2 |
| 7 | Roles & Permissions: `user_store_roles` table, role assignment, enforcement retrofitted across every endpoint built so far (products, sales, categories, units, stock-movements, sync, audit-log reads) — the one deliberately-last item so it retrofits a stable surface rather than a moving one, per [dependency-graph.md §3](../16-milestones/dependency-graph.md#3-the-three-cross-cutting-concerns--deliberately-not-on-the-critical-path)'s own "woven through every node, not sequential" framing — done, [Sprint 23](sprint-23.md); `GET /audit-log` (the "audit-log reads" retrofit target) had never actually been built, so it was built in the same pass rather than retrofitted onto nothing | 1–6 | 3 |
| 8 | Sales & Invoices, full V1 shape: GST invoice fields, canonical invoice numbers assigned at sync, `GET /sales*` server endpoints, permission enforcement — done, [Sprint 24](sprint-24.md); GST invoice fields remain deferred, exactly as anticipated below — tax computation is M2 scope, none of it exists yet | 7 | 3 |

**Total: 15.5 person-days — M1 fully closed, all 8 items done.** Item 8's GST fields genuinely
needed tax computation (M2 scope) to be fully meaningful, as anticipated here before Sprint 24 ran;
its own specification states precisely which GST fields landed (invoice numbering, read endpoints,
permissions — all built) versus which still need M2's tax module first (GST invoice fields
themselves), the same honesty pattern M0's own specs used throughout.

**Correction, found 2026-08-12 (kept for history):** this section never listed Sales & Invoices at
all before this version, despite [dependency-graph.md](../16-milestones/dependency-graph.md)
already fixing it as the module immediately after "POS core loop." **A minimal slice was pulled
forward into Sprint 10**, ahead of M1, at the founder's direct request the moment real device
testing surfaced the gap — a local-only, this-device's-own-sales list/detail view needing none of
M1's actual prerequisites. See
[sales-invoices/specification.md](../modules/sales-invoices/specification.md) §1 for exactly what
that minimal slice is and isn't; item 8 above is what remains.

## 3. M2 — fully decomposed 2026-08-14, now that M1 has reached this point

Per this document's own stated practice (§ intro), M2 is decomposed to item grain only now that
planning has actually reached it — M3–M4 stay at module grain below.

**Real gap found while decomposing (not by writing code first):** [dependency-graph.md §4](../16-milestones/dependency-graph.md#4-settings--a-configuration-input-not-a-graph-dependency)
assumed Settings' fields "simply need sensible defaults present from Setup onward," but no
`shop_settings` row — default or otherwise — is created anywhere in code today; `identity/repository.ts`'s
`createOnboarding` transaction only ever wrote `tenants`/`stores`/the bootstrap `user_store_roles`
row. Discount's auto-approval threshold (DR-012) and Tax's `tax_mode`/`rounding_rule`/`pricing_mode`
both need a real row to read, not a hard-coded constant buried in `pos/service.ts`. Item 1 below
closes that gap before Discount/Tax are attempted, the same "found while planning, not silently
absorbed" practice item 12/13 established for M0 and item 7 for M1.

**A second real gap, in the Phase 07 design itself, not just its implementation:** neither
`shop_settings` nor `products` carries an actual tax **rate** — `shop_settings.tax_mode` only
distinguishes `standard`/`composition`/`unregistered` ([DR-009](../03-functional-requirements/business-rules.md)),
and [DR-008](../03-functional-requirements/business-rules.md)'s `line_tax = round(line_taxable_value
× tax_rate, ...)` formula never named where `tax_rate` itself comes from. Per-HSN-code GST slab
rates (0/5/12/18/28%) would be the fully correct V1 shape, but no rate table exists and building one
is real, undiscussed scope. Resolved here as a dated correction: **`shop_settings` gains a single
shop-wide `tax_rate_basis_points`**, applied to every line when `tax_mode = 'standard'` (forced to
`0` for `composition`/`unregistered`, consistent with DR-009's Bill-of-Supply framing) — a single
flat rate is a real, honest V1 simplification for the overwhelmingly single-rate small shops this
product targets, matching `hsn_sac_code`'s own precedent of staying optional/informational rather
than load-bearing. Per-product/per-HSN rates are deferred, named, not silently implied as already
solved. See [money-and-tax.md](../07-database/money-and-tax.md) and
[schema-server.md](../07-database/schema-server.md) for the corrected `shop_settings` shape.

| # | Item | Depends on | Estimate (person-days) |
| --- | --- | --- | --- |
| 1 | Settings, minimal slice: `shop_settings` table (incl. the `tax_rate_basis_points` correction above), a default row written in the same onboarding transaction as `tenants`/`stores`, `GET`/`PATCH /settings` with the role-shaped read scope [settings.md](../11-api/endpoints/settings.md) already specifies — done, [Sprint 25](sprint-25.md) | — | 1.5 |
| 2 | Cash Drawer / Trading Day: `trading_days` table, `POST /trading-days/open`, `POST /trading-days/{id}/close` (server-computed `expected_cash`/`variance`), `GET /trading-days/current` — done, [Sprint 26](sprint-26.md); scoped per-`(tenant, store)`, not per-device or per-user, a reasoned call made at spec time overriding this row's own "most likely `(tenant, store, user)`" guess (see trading-day/specification.md §1); also built `POST /trading-days/{id}/reopen`, a real gap this row never named; `POST /sales` gains an optional `trading_day_id` but **not** the `TRADING_DAY_NOT_OPEN` hard gate this row anticipated — deliberately deferred to avoid regressing the one live, working end-to-end sale flow this project has, until the mobile till screen pairs with it | — | 2.5 |
| 3 | Discount: per-line `discount_percent`/`discount_amount` in `POST /sales` (mutually exclusive, [DR-011](../03-functional-requirements/business-rules.md)), server-computed `line_discount_minor_units`, threshold check against `shop_settings.discount_auto_approval_threshold_minor_units` ([DR-012](../03-functional-requirements/business-rules.md)) gating on role per [DR-019](../03-functional-requirements/business-rules.md)/[DR-020](../03-functional-requirements/business-rules.md) | 1 | 2 |
| 4 | Tax computation: `tax_mode`/`tax_rate_basis_points`/`rounding_rule`/`pricing_mode` wired into `POST /sales` per [money-and-tax.md](../07-database/money-and-tax.md)'s discount-before-tax formulas (both exclusive and inclusive worked examples), `tax_registration_type_at_sale` snapshot, the GST invoice fields [sales-invoices/specification.md](../modules/sales-invoices/specification.md) named deferred at Sprint 24 | 1, 3 | 2.5 |
| 5 | Split Payment: `POST /sales` accepts multiple `payments` entries (`cash`/`card`/`other`), validated against the server-recomputed `grand_total_minor_units` (`PAYMENT_AMOUNT_MISMATCH` restated for the multi-entry case); cash-only sum feeds Trading Day's `expected_cash_minor_units` — schema already supports multiple `sale_payments` rows per sale (M0's `SalePayment` is a relation, not a single field), so this is validation/wiring, not a new table | 2, 4 | 1.5 |
| 6 | Hold/Resume: `sales.status` transitions `draft`→`held`→`completed` on the client; per [sales.md](../11-api/endpoints/sales.md)'s own note a held/draft cart is never synced to the server as a partial row, so this is primarily mobile local-DB/UI work (till-screen hold list, resume-into-cart) — the server accepts a completed sale exactly as it does today regardless of what local lifecycle produced it | — | 2 |

**Total: 12 person-days.** Items 1–2 done — see the Change Log. M2 now has items 3–6 remaining.

## 3a. M3–M4 — module grain only, decomposed when reached

| Milestone | Modules (decomposition pending) |
| --- | --- |
| M3 | Customers, Returns & Refund, conflict-resolution field-merge |
| M4 | Reports (4), release-readiness closeout (printer/device testing, load test, adversarial suite in CI) |

## 4. Ordering rule, restated

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
| 0.10.0 | 2026-08-13 | Item 11 (end-to-end proof) opened — [Sprint 16](sprint-16.md): the exact step-by-step script written, a rebuilt APK carrying every Sprint 11–15 change re-served to the founder. In progress — blocked on the founder's own execution and, for the print step, physical printer hardware. |
| 0.11.0 | 2026-08-14 | Item 11 steps 1–7 confirmed working by the founder — no bug found on the first real end-to-end run. Step 8 (physical print) remains open, blocked on printer hardware; M0 stays open until it closes too. |
| 0.12.0 | 2026-08-14 | M1 fully decomposed (8 items, 15.5 person-days) — founder directed M1 to begin now despite item 11's physical-print step remaining open (external hardware, not engineering work; see modules/README.md Rule 2's third exception). |
| 0.13.0 | 2026-08-14 | Item 2 (units) done — [Sprint 18](sprint-18.md): `POST`/`GET /units` built and live-verified, direct sibling of item 1 (Categories). `PATCH`/`DELETE`/`UNIT_FRACTIONAL_FLAG_LOCKED` deferred for the same reason Categories' were. M1 now has items 3–8 remaining. |
| 0.14.0 | 2026-08-14 | Item 3 (extend products) done — [Sprint 19](sprint-19.md): `category_id`/`unit_id`/`sku`/`barcode`/`hsn_sac_code` added to `POST /api/v1/products`, live-verified, 9/9 checks. Corrected this row's own "required" wording to "optional" — 4 real production products and mobile's still-unchanged `/catalogue/add` shape made "required" break on contact with reality; found by querying the live database before writing code. M1 now has items 4–8 remaining. |
| 0.15.0 | 2026-08-14 | Item 4 (mobile catalogue UI) done — [Sprint 20](sprint-20.md): `/catalogue/categories`/`/catalogue/units` built, `/catalogue/add` now requires a category/unit selection. Found and corrected a real gap: the sync engine has no `category.create`/`unit.create` push type, so creation is online-only (`shop_settings`' own existing local-schema precedent applied, not a new pattern). `flutter test` 89/89. M1 now has items 5–8 remaining. |
| 0.16.0 | 2026-08-14 | Item 5 (barcode/SKU search) done — [Sprint 21](sprint-21.md): `GET /api/v1/products` built and live-verified (7/7); till screen gains search/category-filter/barcode-scan, resolved locally per FR-034/FR-036's "Fully offline" classification. Found and fixed a real Sprint 20 gap: sync pull never carried category_id/unit_id/sku/barcode to devices. `flutter test` 94/94. M1 now has items 6–8 remaining. |
| 0.17.0 | 2026-08-14 | Item 6 (full stock-movement types) done — [Sprint 22](sprint-22.md): `adjustment`/`reason_code`, `POST`/`GET /api/v1/stock-movements`, `GET /api/v1/products/{id}/stock-balance` built and live-verified (9/9). Found while writing the spec: the endpoint does not accept `movement_type: 'opening'` after all — every product already gets one automatically at creation, so there's no live caller for a second, direct one — a named, dated deviation from inventory.md's original documented contract. M1 now has items 7–8 remaining. |
| 0.18.0 | 2026-08-14 | Item 7 (Roles & Permissions) done — [Sprint 23](sprint-23.md): `user_store_roles` table, `GET/POST/PATCH/DELETE /users*` built and live-verified (12/12 for the role-management chain; `POST /users/invite` itself confirmed separately before hitting Supabase's own email rate limit). Permission enforcement retrofitted across every existing endpoint. Three real gaps found and closed in the same pass: onboarding never assigned a role, `GET /audit-log` was named as a retrofit target but never built, `POST /users/invite`'s "pending record" mechanism resolved via Supabase Admin's synchronous `inviteUserByEmail`. M1 now has only item 8 remaining. |
| 0.19.0 | 2026-08-14 | Item 8 (Sales & Invoices, full V1 shape) done — [Sprint 24](sprint-24.md): canonical invoice numbers (ADR-0008's atomic counter) and `GET /sales/{id}`/`GET /sales`/`GET /sales/lookup` built and live-verified (7/7). GST invoice fields remain explicitly deferred (M2, tax computation doesn't exist) — exactly as this item's own estimate anticipated. **M1 is now fully closed — all 8 items done.** |
| 0.20.0 | 2026-08-14 | M2 fully decomposed (6 items, 12 person-days) — Settings, Trading Day, Discount, Tax computation, Split Payment, Hold/Resume, in dependency order. Two real gaps found while decomposing (not by writing code first): (1) no `shop_settings` row is created anywhere in code, despite dependency-graph.md assuming "sensible defaults... from Setup onward" — added as item 1, a hard prerequisite for Discount/Tax; (2) neither `shop_settings` nor `products` ever named where DR-008's `tax_rate` actually comes from — resolved as a dated correction, a single shop-wide `tax_rate_basis_points` on `shop_settings` (per-HSN slab rates explicitly deferred, not silently assumed solved). Trading Day's `device_id NOT NULL` FK to a still-nonexistent `devices` table is named as a known open point, deliberately not resolved until that item's own sprint, matching Sprint 24's own precedent for exactly this shape of gap. |
| 0.21.0 | 2026-08-14 | Item 1 (Settings, minimal slice) done — [Sprint 25](sprint-25.md): `shop_settings` table, a default row now written at onboarding, `GET`/`PATCH /api/v1/settings` built and live-verified (26/26). M2 now has items 2–6 remaining. |
| 0.22.0 | 2026-08-14 | Item 2 (Cash Drawer / Trading Day) done — [Sprint 26](sprint-26.md): `trading_days` table, `POST /trading-days/open`/`{id}/close`/`{id}/reopen`, `GET /trading-days/current` built and live-verified (26/26). Scoped per-store, not per-device/per-user — a reasoned override of this item's own pre-sprint guess. Built the reopen endpoint, a real gap this item never named. `POST /sales`'s `TRADING_DAY_NOT_OPEN` hard gate deliberately deferred, reversing this item's own plan, to avoid a real regression of the one live E2E sale flow this project has. M2 now has items 3–6 remaining. |
