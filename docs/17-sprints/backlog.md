# Backlog

> **Status:** 🔵 In review
> **Phase:** 17 — Sprint Planning
> **Version:** 0.62.0
> **Last updated:** 2026-08-21
> **Owner:** Product Manager / CTO
> **Approved by:** _pending_

Ordered, estimated, with dependencies. **M0, M1, M2, and M3 are decomposed in full, item by item, in
the order planning actually reached them; M4 is still listed at module grain only** — per this
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
| 3 | Discount: per-line `discount_percent`/`discount_amount` in `POST /sales` (mutually exclusive, [DR-011](../03-functional-requirements/business-rules.md)), server-computed `line_discount_minor_units`, threshold check against `shop_settings.discount_auto_approval_threshold_minor_units` ([DR-012](../03-functional-requirements/business-rules.md)) gating on role per [DR-019](../03-functional-requirements/business-rules.md)/[DR-020](../03-functional-requirements/business-rules.md) — done, [Sprint 27](sprint-27.md); found and corrected a real gap in the same pass: `sales.subtotal_minor_units` had silently meant "pre-discount raw sum" rather than money-and-tax.md's always-specified post-discount value, invisible until this item made the two diverge | 1 | 2 |
| 4 | Tax computation: `tax_mode`/`tax_rate_basis_points`/`rounding_rule`/`pricing_mode` wired into `POST /sales` per [money-and-tax.md](../07-database/money-and-tax.md)'s discount-before-tax formulas (both exclusive and inclusive worked examples), `tax_registration_type_at_sale` snapshot — done, [Sprint 28](sprint-28.md); found and resolved a real gap in money-and-tax.md's own two worked examples in the same pass (inclusive pricing + a discount on the same line was never jointly specified); the GST invoice **document-rendering** fields [sales-invoices/specification.md](../modules/sales-invoices/specification.md) named deferred at Sprint 24 remain deferred — this item computes the numbers, Receipt & Printing owns the document layout | 1, 3 | 2.5 |
| 5 | Split Payment: `POST /sales` accepts multiple `payments` entries (`cash`/`card`/`other`), validated against the server-recomputed `grand_total_minor_units` (`PAYMENT_AMOUNT_MISMATCH` restated for the multi-entry case); cash-only sum feeds Trading Day's `expected_cash_minor_units` — schema already supports multiple `sale_payments` rows per sale (M0's `SalePayment` is a relation, not a single field), so this is validation/wiring, not a new table — done, [Sprint 29](sprint-29.md); confirmed live that Trading Day's own Sprint 26 aggregation query needed no change at all to already exclude a split sale's card/other portions correctly | 2, 4 | 1.5 |
| 6 | Hold/Resume: `sales.status` transitions `draft`→`held`→`completed` on the client; per [sales.md](../11-api/endpoints/sales.md)'s own note a held/draft cart is never synced to the server as a partial row, so this is primarily mobile local-DB/UI work (till-screen hold list, resume-into-cart) — done, [Sprint 30](sprint-30.md); built to navigation-model.md §4's fuller "continuous auto-persistence from the first item added" requirement, a real gap this row's own wording didn't name; the server accepts a completed sale exactly as it does today regardless of what local lifecycle produced it, unchanged | — | 2 |

**Total: 12 person-days.** Items 1–6 done. **M2 — Full POS Loop is now fully closed, all 6 items done.**

**Correction, found Sprint 60 (checking every milestone's own exit criterion against what was
actually verified at closure, the same discipline Sprints 58/59 applied to M4's release gate):**
"all 6 items done" is true and remains the honest basis for this section's own scope — but
[milestones.md](../16-milestones/milestones.md)'s **M2 row** states a *different*, stricter
exit criterion that this closure never actually satisfied: "the full
[tap-count-audit.md](../09-navigation/tap-count-audit.md) budget is met on every Till workflow,
**measured on the reference low-end device**..., **not estimated**." `tap-count-audit.md` is
explicitly a design-time trace (Phase 09, v0.1.0), never a physical measurement; the reference
device it names has never been owned, unchanged from Sprint 43 through today (M4 item
9/MTS-03/device-matrix.md's own still-open finding). M0 and M4 — this project's other two
milestones with a hardware-dependent exit criterion — were each closed with an explicit,
honest caveat naming exactly this gap (Sprint 16's "step 8 remains open, blocked on printer
hardware"; M4 never actually closed at all, still correctly tracked open via
release-checklist.md). This entry's own "fully closed" line carried no equivalent caveat when
written (Sprint 30) and none since — corrected here, not by weakening the claim (all 6 backlog
items genuinely are done) but by naming the real, still-open gap between that and
milestones.md's own stricter exit-criteria text for this specific milestone.

## 4. M3 — fully decomposed 2026-08-16, now that M2 has reached this point

Per this document's own stated practice (§ intro), M3 is decomposed to item grain only now that
planning has actually reached it — M4 stays at module grain below.
[dependency-graph.md §2](../16-milestones/dependency-graph.md#2-the-critical-path-named-explicitly)
places Customers and Returns as parallel branches off Sales & Invoices with no dependency on each
other, **except** a `Customers → Returns` edge — traced here (not previously explained anywhere) to
[returns-workflows.md](returns-workflows.md)'s WF-012 step 1: locating the original sale "by
receipt, invoice number, or customer phone" ([FR-062](../03-functional-requirements/functional-requirements.md))
needs the Customers module's phone-search to exist first for that third path to work at all — not a
server-schema dependency (`returns` has no FK to `customers`), only a mobile-flow one. Item order
below follows the graph regardless.

**A real, previously-invisible gap found while decomposing, not by writing code first:** the sync
engine (`apps/web/src/modules/sync/service.ts`) has supported exactly two operation types since
Sprint 13 — `product.create` and `sale.create` — and **no `.update` operation type exists for any
entity at all**, despite [entity-classification.md](../13-offline-sync/entity-classification.md)
already classifying `categories`/`units`/`products`/`customers` as "Client-editable" (bidirectional,
needing [conflict-resolution.md](../13-offline-sync/conflict-resolution.md)'s field-merge policy)
since Phase 13. That policy has been fully specified on paper since 2026-07-31 and never had a single
line of implementation to exercise it — M3's item 5 below is genuinely new sync-engine capability,
not incremental wiring onto existing infrastructure the way M2's items mostly were. Scoped to
`customers` only, matching [milestones.md](../16-milestones/milestones.md)'s own M3 exit criterion
("a field-edit conflict on a customer record... surfaces in the exact business-language form"), not
speculatively generalised to `categories`/`units`/`products` — none of which has a mobile *edit*
screen built yet either (M1 items 1/2 explicitly deferred `PATCH`/`DELETE` for both), so there is no
real caller for that generalisation today. The mechanism built here is reusable when that changes;
building it now for entities with no edit UI would be exactly the kind of speculative abstraction
this project's own practice avoids.

**A second real gap found the same way:** [offline-workflows.md Finding 1](../06-workflows/offline-workflows.md#finding-1--offline-approvals-are-provisional-until-sync-and-that-needs-a-defined-ux)
(an offline return/discount approval rejected post-hoc if the approving Manager's role was revoked
before sync) was resolved *on paper* in
[failure-scenarios.md §2](../13-offline-sync/failure-scenarios.md#2-resolving-finding-1--provisional-approvals-rejected-after-the-fact)
via a `sync_rejections` table and an Owner-facing review flow — but `sync_rejections` has no Prisma
model and no code anywhere; it was never built. Returns' `POST /returns/{id}/approve` is exactly the
workflow this risk applies to (WF-013, genuinely offline-capable per
[returns.md](../11-api/endpoints/returns.md)). Item 3 below builds the actual correctness the risk
requires — the sync-push handler re-validates the approver's role server-side at sync time and
rejects the operation if it was revoked (DR-017/DR-018, the same "resolved fresh at request time"
principle Discount's `DISCOUNT_REQUIRES_APPROVAL` already established, M2 item 3) — but the dedicated
`sync_rejections` table and Owner-facing "review and decide what happens to this rejected sale/return"
screen are **explicitly deferred**, named here rather than silently dropped: neither
[milestones.md](../16-milestones/milestones.md)'s M3 exit criteria nor any built screen today
requires it, and it is real, separate scope (an Owner-facing review workflow, arguably nearer M4's
Reports/release-readiness territory) — the same kind of reasoned, dated deferral M2's Trading Day
item (Sprint 26) already set precedent for with `TRADING_DAY_NOT_OPEN`.

| # | Item | Depends on | Estimate (person-days) |
| --- | --- | --- | --- |
| 1 | Customers (server): `customers` table (new migration + RLS, Tier 1) per [schema-server.md](../07-database/schema-server.md), `sales.customer_id` FK (nullable, `ON DELETE SET NULL`, new migration), `POST`/`GET`/`PATCH`/`DELETE /customers`, `GET /customers/{id}/purchase-history` — [customers.md](../11-api/endpoints/customers.md), FR-050/051/052 — done, [Sprint 31](sprint-31.md); found and fixed a real bug live: a Zod `.refine()` for "at least one identifier" always returned the generic `VALIDATION_FAILED` instead of the documented `CUSTOMER_IDENTIFIER_REQUIRED`, moved to the service layer; corrected permission-matrix.md's own missing edit/deactivate rows in the same pass | — | 2.5 |
| 2 | Customers (mobile): local `customers` Drift table, `/customers` list with phone-match-as-you-type search (FR-052), `/customers/:id` detail with purchase history (FR-051), inline capture/select wired into the till's checkout flow (FR-050, offline-queued create) — done, [Sprint 32](sprint-32.md); built as a full-stack item, not mobile-only, since it also needed the `customer.create` sync-push type and `POST /sales` accepting `customer_id`, both named-but-deferred in Sprint 31; `CustomerPickerSheet` built as a bottom sheet over the till screen (FR-050's "without leaving the sale screen," taken literally), not a route push | 1 | 2.5 |
| 3 | Returns & Refund (server): `returns`/`return_line_items` tables (new migration + RLS, Tier 2), `POST /returns` (auto-approve vs. `pending_approval` against `shop_settings.return_auto_approval_threshold_minor_units`, DR-013–016), a `return` stock-movement created atomically in the same transaction (the already-specified, not-yet-built counterpart to `sale`/`opening`, per [stock-ledger.md](../07-database/stock-ledger.md)), `GET /returns/{id}`/`GET /returns`/`GET /returns/approvals`, `POST /returns/{id}/approve`/`reject` (interrupt/queue split, [tap-count-audit.md](../09-navigation/tap-count-audit.md)) — [returns.md](../11-api/endpoints/returns.md), WF-012/WF-013 — done, [Sprint 33](sprint-33.md); found and corrected two real schema gaps while writing the spec: `returns` needed a `created_by`/`created_at` column pair schema-server.md never listed, and its documented separate `client_operation_id` column had no working precedent anywhere else in this schema (dropped in favour of `id` alone, matching every other client-generated-id table) | 1 | 3 |
| 4 | Returns & Refund (mobile): `/returns/new` (locate the original sale via `GET /sales/lookup` or via a customer's purchase history), `/returns/:id`, `/returns/approvals` (Manager+, queue badge per [navigation-model.md](../09-navigation/navigation-model.md)), local `returns`/`return_line_items` tables + outbound-queue enqueue for create/approve/reject — done, [Sprint 34](sprint-34.md); found and fixed a real, blocking gap live: no server response exposed a sale line item's own `id`, which `POST /returns` needs — fixed additively in `pos/service.ts`'s `formatSale`. Badge placement (no Reports tab exists yet) and the WF-013 interrupt/queue split (no realtime infrastructure exists) both resolved as dated, documented decisions rather than left implicit | 2, 3 | 2.5 |
| 5 | Conflict-resolution field-merge, `customers` only: sync push gains a `customer.update` operation type; base-`updated_at` comparison, non-overlapping-field auto-merge, same-field-different-value surfaces the exact business-language prompt [conflict-resolution.md](../13-offline-sync/conflict-resolution.md) specifies (worked example given verbatim for a customer's `phone` field) — the sync engine's first `.update` operation type of any kind, see the gap named above — done, [Sprint 35](sprint-35.md); found and resolved a real gap while writing the spec: `base_updated_at` alone can't support a field-level 3-way merge, resolved by having the client send each field's own base value too; `PATCH /customers/{id}` itself upgraded to the merge-aware shape (a genuine, dated contract break, judged safe since no mobile caller of `PATCH` ever existed) | 1, 2 | 3 |

**Total: 13.5 person-days. M3 — Customers & Returns is now fully closed, all 5 items done.**

## 5. M4 — fully decomposed 2026-08-16, now that M3 has reached this point

Per this document's own stated practice (§ intro), M4 is decomposed to item grain only now that
planning has actually reached it. Unlike M1–M3, M4's scope is not a chain of interdependent features
— [dependency-graph.md §2](../16-milestones/dependency-graph.md#2-the-critical-path-named-explicitly)
already places Reports as a branch off Sales & Inventory with no further downstream dependents, and
Settings' remaining scope and release-readiness closeout are independent of both Reports and each
other. Items below are grouped by theme, not chained end-to-end; the `Depends on` column reflects the
real, narrower dependencies that exist, not an artificial sequencing.

**A real, previously-undocumented-as-built gap found while decomposing (not by writing code first):**
[sync-api.md §6](../11-api/sync-api.md#6-pull--get-syncpull) has, since Phase 11, already named
`stock_movements` and `sales` from *other* devices as pull targets "for reporting parity across
devices in a future multi-device store" — but `sync/schema.ts`'s `entity_type` enum has only ever
implemented `products` (Sprint 13). Per [FR-071](../03-functional-requirements/functional-requirements.md#group-j--reports-core-four)'s
own offline-behaviour column ("computed from locally synced data; may be incomplete for a
multi-device shop until fully synced"), the Reports module is specified to read local data only — no
`reports.md` endpoint document exists anywhere in [11-api/endpoints/](../11-api/endpoints/), and none
is needed. That means Reports is silently load-bearing on a pull capability that was named on paper
in Phase 11 and never built. Item 1 below closes that gap first, the same "found while planning, not
silently absorbed" practice item 1 set for M2 (`shop_settings`) and item 5 set for M3 (`.update` sync
operations).

**A second real point, named rather than silently accepted:** because Reports has no server endpoint
of its own (per the gap above, it reads only already-synced local data), [permission-matrix.md —
Reports](../05-personas/permission-matrix.md#reports)'s Manager/Owner-only restriction has no server
call to enforce it against — the underlying sales/stock data is, by design, already resident on
every synced device regardless of the signed-in user's role, once item 1 lands. Item 2's own
Manager/Owner gate is therefore necessarily a client-side presentation control, not a data-access
boundary — a deliberate, accepted exception to this project's otherwise-consistent "never merely
hidden in the UI" stance (stated for every other permission row to date), justified narrowly because
there is no cross-tenant or cross-role data exposure at stake (every role's device already holds the
same shop-wide operational data it needs to keep selling offline) — only a business-sensitivity
preference about who sees aggregated figures, which a client-side gate does satisfy honestly.

**A third real gap, a documentation inconsistency rather than a missing capability:** see
[milestones.md](../16-milestones/milestones.md)'s own dated correction — M4's Scope line named "the
10× load test" as milestone content, but M4's Exit criteria row already restricts the milestone to
[release-checklist.md](../14-testing/release-checklist.md)'s **pilot-ready** tier (§2), and the load
test is a **commercial-launch-ready** gate (§3). No load-test item appears below as a result; it
remains real, tracked scope for whenever commercial launch is actually approached.

**A fourth real gap, found by checking the actual repository rather than trusting phase documents:**
[ci-pipeline.md §3](../14-testing/ci-pipeline.md#3-nightly-pipeline) and
[offline-test-suite.md](../14-testing/offline-test-suite.md) both already specify a nightly pipeline
and a toxiproxy-based adversarial sync harness in full detail — neither exists. `.github/workflows/`
contains only `pr.yml`; no cross-tenant isolation suite, no idempotent-replay/concurrent-composition
integration tests, and no failure-scenario harness exist anywhere in the repository today, despite
[security-test-plan.md §1](../12-security/security-test-plan.md#1-cross-tenant-isolation) and
[13-offline-sync/test-plan.md](../13-offline-sync/test-plan.md) having fully specified both since
Phase 12/13. Every table built across M0–M3 (22 of them) has RLS applied per-table at the point it
was created, but the **independent, automated, CI-enforced proof** [tenant-isolation.md](../12-security/tenant-isolation.md)
requires has never been written as its own suite. Items 5–7 below build this — genuinely new
engineering, not wiring onto existing infrastructure, the same shape M3's item 5 (`.update` sync
operations) turned out to be.

| # | Item | Depends on | Estimate (person-days) |
| --- | --- | --- | --- |
| 1 | Sync pull, reporting parity: `GET /sync/pull` gains `stock_movements` and `sales` entity types (this device's own local `sale_line_items` included in each pulled sale's payload, matching `GET /sales/{id}`'s existing shape), pulled from every device in the tenant/store, not just the calling device's own; mobile upsert-by-id into the existing local `stock_movements`/`sales` tables, deduplicated against rows the device itself already wrote locally (same id, no-op) — the real gap named above — **done, [Sprint 36](sprint-36.md)**; found a second real gap while implementing: a single `next_cursor` field can't carry both "keep paging now" and "durable resume point for next cycle" at once for an ever-growing entity type, resolved by adding a distinct `has_more` field for these two types only (sync-api.md §6, dated correction) and a new local `sync_cursors` table for mobile to persist against; live-verified 24/24 | — | 2.5 |
| 2 | Reports (mobile, local aggregation only, Manager/Owner client-side gate): daily sales total + trailing 7 days (FR-071), stock value = Σ(derived balance × price basis) (FR-072), products ranked by qty/value over a selected date range (FR-073), low-stock list sorted by distance below threshold (FR-074) — four screens computed entirely from the local Drift DB now populated by item 1, no new server endpoint (§ above) — **done, [Sprint 37](sprint-37.md)**; found two further real gaps while starting it: no low-stock threshold configuration existed anywhere (added `shop_settings.low_stock_threshold_quantity`, live-verified 11/11), and `shop_settings` had never been synced to mobile at all (added as sync pull's 4th entity type); built this codebase's first genuine client-side role-awareness (a cached, fail-closed `GET /users` permission probe) to gate the Reports entry point | 1 | 3 |
| 3 | Settings, mobile UI: `/settings` route (Owner-edit, Manager/Cashier read-only per the already-built role-shaped `GET /settings` response) surfacing tax mode/rate/pricing mode/rounding rule/currency — the first mobile screen to actually read or write any of these fields, which have been server-complete since Sprint 25 but never had a UI — **done, [Sprint 38](sprint-38.md)**; no server change needed (already complete); built as Pattern B (reachable by every role, server's own `403`/role-shaped response does the gating), the opposite of Reports' hide-entirely Pattern A, since this screen's `GET /settings` is itself a real, already role-shaping network call — named explicitly since it's the same choice `return_approvals_screen.dart` made; found a real spec-currency gap while writing the module spec update (Sprint 37's `low_stock_threshold_quantity` had never been folded into `settings/specification.md`'s own Change Log) | — | 1.5 |
| 4 | Settings, printer pairing + receipt template (FR-077/FR-078) — **done, [Sprint 39](sprint-39.md)**; mobile `/settings/printer` (pairing + test-print, reusing Sprint 15's Bluetooth ESC/POS transport, printer persisted in a new local-only `PairedPrinterCache`) and `/settings/receipt-template` (footer-message editor, the one field receipt-design.md names as customisable). Two corrections to this item's own original framing, found while writing the spec: `PATCH /settings` accepts `receipt_template_config` now but with exactly one field, not a broader togglable shape — `RECEIPT_TEMPLATE_MISSING_MANDATORY_FIELD` stays deliberately unreachable (GSTIN, the only real conditional-mandatory candidate, isn't captured in `shop_settings` at all — a separate, larger gap); `printer_config` stays untouched — pairing is per-device data with no `devices` table to belong to, resolved entirely client-side instead. Live-verified 7/7 | 3 | 2.5 |
| 5 | Cross-tenant isolation suite, CI-enforced: automated negative tests against a real authenticated connection (not API-code inspection) for all 22 tables per [tenant-isolation.md §2](../12-security/tenant-isolation.md#2-what-every-table-means-precisely-restated-as-a-checklist)'s four categories, plus the Realtime-channel extension (§4) — wired into `pr.yml` as a blocking stage per [ci-pipeline.md §2](../14-testing/ci-pipeline.md#2-pipeline-stages--every-pull-request) — **done, [Sprint 40](sprint-40.md)**; found the "22 tables" figure itself was stale (5 listed tables never built, 2 real tables never listed, one miscategorised — corrected to 19); found and closed a real, previously-undetected gap building the suite — `sale_line_items`/`sale_payments`/`return_line_items` had **no RLS at all**, contradicting the schema's own design template; Realtime extension deliberately deferred (needs the full local Supabase CLI stack, a materially larger scope), named not silently dropped; `fast-integration` runs against a fresh `postgres:15` container on every PR, no path filter | — | 3 |
| 6 | Offline adversarial suite in CI: idempotent-replay + 2-device concurrent-composition + 1-of-10 server-testable failure scenarios as a fast `pr.yml`-blocking stage; N-device fuzzed composition (100 runs) written, nightly-gated (item 7 wires it) — **done, [Sprint 41](sprint-41.md)**; found no toxiproxy/new CI infra was actually needed for the PR-gated subset (replay/order-independence are server-observable, proven against the same `postgres:15` container Sprint 40 already built); found and fixed a real, previously-unverified concurrency gap in `sale.create`/`return.create`/`return.approve`'s replay safety (a read-then-write race under genuine concurrent requests, not sequential replay); found `test-plan.md §3`'s "one test per row" (10 failure scenarios) conflated three different test venues — only 1 row was actually a server integration test, the rest are mobile-only, need the full Supabase CLI stack, or already need no test at all, named not silently dropped | — | 4 |
| 7 | Nightly CI pipeline: new `.github/workflows/nightly.yml` wiring items 5/6's slow subsets, plus Dependabot-based dependency audit ([ci-pipeline.md §3](../14-testing/ci-pipeline.md#3-nightly-pipeline)) — release-candidate-blocking, not same-day-merge-blocking, per that document's own rule — **done, [Sprint 42](sprint-42.md)**; found item 5 has no distinct "slow subset" ready (its only deferred piece, the Realtime extension, needs the full Supabase CLI stack, unbuilt) and item 6's own slow subset is just the N-device fuzz test — that alone is nightly.yml's real content, plus `.github/dependabot.yml`; found `ci-pipeline.md §3`'s "full failure-scenario suite"/"extended property-based tests" rows have no code to run at all, on any tier — the former because Sprint 41 found only 1 of 10 scenarios is server-testable (already PR-gated), the latter because no property-based suite was ever built despite `test-strategy.md §1` claiming DR-008/DR-013 coverage from it — both corrected as real, dated gaps, not silently stubbed; no `release-candidate.yml` exists to actually gate on a nightly failure, so built a standing-GitHub-issue-on-failure mechanism as this sprint's real substitute for that rule's intent | 5, 6 | 1 |
| 8 | OWASP checklist review against the actual release build: walk [owasp-checklist.md](../12-security/owasp-checklist.md)'s already-complete design-time traceability table against the real, running M0–M4 codebase (not the design docs it cites), confirming each mitigation is actually present in code, not just specified on paper — **done, [Sprint 43](sprint-43.md)**; 4 of 20 rows genuinely fixed in the same pass (security headers; a real DR-025 audit-log-coverage gap spanning 4 movement types + settings changes, unfixed since Sprint 12 despite being self-identified then); 6 real gaps found and named, not silently fixed or dropped — two carry real production risk and are flagged for the founder (RLS's defence-in-depth layer is very likely inert for all real traffic today, pending confirmation of the actual production database role; rate limiting is entirely unimplemented despite being claimed built); four are real, bounded future engineering (mobile secure token storage, on-device database encryption, customer-erasure anonymisation, security alerting/monitoring); one is founder-blocked (Android release build signs with the debug keystore, needs real production signing credentials this session cannot generate) | 1–7 | 1 |
| 9 | MTS-01/02/03 executed and evidenced: scripts already fully written in [manual-test-scripts.md](../14-testing/manual-test-scripts.md); execution itself is a founder action blocked on physical printer hardware (MTS-01) and the reference low-end device (MTS-03) per [device-matrix.md §3](../14-testing/device-matrix.md#3-this-is-a-founder-action-not-an-engineering-one--stated-plainly) — the same named, non-blocking-until-it-blocks shape M0's own item 11 established for exactly this kind of gap | 1–8 | 1 |

**Total: 19.5 person-days.** Items 5, 6, and 9 are the ones most likely to reveal further real gaps
once actually attempted — no CI-enforced isolation or adversarial-sync suite has ever been run
against this codebase before, and item 9 remains genuinely blocked on hardware the founder does not
yet own, tracked the same way M0's own physical-print step was.

**Cross-cutting closeout, [Sprint 44](sprint-44.md) (not a numbered item — a direct consequence of
item 8's own findings):** with items 1–8 done, [release-checklist.md §2](../14-testing/release-checklist.md#2-pilot-ready-checklist)
(this milestone's actual exit criterion, per [milestones.md — M4](../16-milestones/milestones.md#m4--reports-settings-and-release-readiness))
was checked against Sprints 40–43's real results for the first time since it was written. Two rows
were stale (22 tables/Realtime; "all 10 failure scenarios") and corrected to match what was actually
built. The honest conclusion, stated in that document rather than left implicit: **this product is
not pilot-ready today** — four rows are unresolved, only one of which (MTS execution, item 9) was
already tracked; the other three (the nightly suite's first real scheduled run still pending, 9 of
10 failure scenarios having zero verification of any kind, and the OWASP review's two unresolved
findings) are new information surfaced by this same pass, not previously named as open risks against
this specific gate.

**Cross-cutting fix, [Sprint 45](sprint-45.md) (not a numbered item — closes finding #2 from item
8's OWASP review):** rate limiting, fully specified in
[rate-limiting.md](../11-api/rate-limiting.md) since Phase 11, was entirely unimplemented. Built for
the 3 endpoint classes actually reachable from this codebase (mutating/read/sync-push — a
Postgres-backed fixed-window counter inside `requirePermission`, no external service). Found the
Auth class (sign-in/OTP) is architecturally unreachable from this codebase at all — sign-in never
touches an `apps/web` Route Handler — a real, named gap needing a Supabase-side configuration check,
not code. Unlike the RLS finding (item 8's other flagged risk, deliberately left open pending founder
input since a wrong fix risks an outage), this one carried no such risk and was safe to close
immediately.

**Cross-cutting fix, [Sprint 46](sprint-46.md) (not a numbered item — closes finding M6 from item
8's OWASP review):** customer-erasure anonymisation, fully designed in
[privacy.md §4](../12-security/privacy.md#4-deletion--reconciling-erasure-rights-with-ledger-immutability)
since Phase 12, had zero implementation. Built `POST /customers/{id}/erase` (Owner only) — nulls
`name`/`phone`, sets a new `erased_at` marker, preserves an existing `deactivated_at` rather than
overwriting it. Found and fixed a related, previously-unexposed gap in the same pass: `deactivated_at`
had never been surfaced in any customer API response at all. Like Sprint 45's rate limiting, this
carried no production-configuration risk and was safe to close immediately.

**Cross-cutting fix, [Sprint 47](sprint-47.md) (not a numbered item — closes finding M1 from item
8's OWASP review):** mobile secure token storage. `flutter_secure_storage` was a `pubspec.yaml`
dependency but was never imported anywhere in `apps/mobile/lib` — the Supabase session sat in
plaintext `SharedPreferences` on Android. Built `SecureLocalStorage` (`core/auth/`), wired into
`Supabase.initialize`, tested via a genuine in-memory fake rather than mocking the platform channel.
No migration from the old plaintext value — a dated decision, no real installed base exists yet.
Like Sprints 45/46, this carried no production-configuration risk and was safe to close immediately.

**Cross-cutting fix, [Sprint 48](sprint-48.md) (not a numbered item — closes finding M9 from item
8's OWASP review):** on-device database encryption. `data-protection.md §3` decided on SQLCipher
since Phase 12 but deferred the exact integration package to actual implementation time; the
ecosystem had moved since then (`sqlcipher_flutter_libs` is now a no-op stub) — the real
integration is a `pubspec.yaml` declaration (`package:sqlite3` 3.x's native-hooks mechanism), not a
plugin dependency. Built `getOrCreateDatabaseEncryptionKey` and `AppDatabase.encrypted`, keyed via
SQLCipher's raw-key `PRAGMA key` form. Unlike Sprints 45–47, this carried real risk to local test
data (not just a trivial re-sign-in), so a legacy plaintext database file is detected and reset
once rather than migrated, and the fix was verified against a real Android debug build
(`libsqlcipher.so` confirmed bundled in the APK) plus a dedicated test proving unkeyed reads
genuinely fail, not just that no error is thrown.

**Cross-cutting closeout, [Sprint 49](sprint-49.md) (not a numbered item — a direct consequence of
Sprints 45–48's own findings, the same shape Sprint 44 itself took):** with four more of item 8's
OWASP findings now closed, `release-checklist.md §2` (M4's actual exit criterion) was checked
against Sprints 45–48's real results for the first time since Sprint 44's own pass. One row
genuinely flips to satisfied — `nightly.yml` has now really fired on its own schedule and passed,
confirmed via `gh run list`, not assumed. One row's wording was corrected rather than left stale:
general rate limiting is built (Sprint 45), narrowing the remaining OWASP gap to sign-in
specifically (architecturally unreachable, needs a Supabase-side check). RLS and the 9 unverified
failure scenarios were re-confirmed unchanged rather than silently assumed. Honest bottom line,
unchanged in direction but smaller in scope: this product is still not pilot-ready today, now three
unresolved rows instead of four. No code changes.

**Cross-cutting fix, [Sprint 50](sprint-50.md) (not a numbered item, not a re-opening of item 6):**
2 of the 9 unverified offline failure scenarios named in test-plan.md §3 — "App killed mid-sync,"
"Device rebooted with a full queue" — turned out to be fully testable with existing `flutter test`
infrastructure, no new tooling needed, once actually attempted rather than assumed to need the same
infra as the genuinely-deferred rows. Found and corrected a real doc/code gap while writing the
test: the mobile client's `SyncRepository` never writes the `Syncing` transitional status
state-machines.md's own Sync Item diagram specifies — the safety guarantee still holds, via a
simpler real mechanism (an interrupted row is left untouched and naturally resent next cycle,
server-side idempotent upsert making the resend safe), corrected across state-machines.md,
failure-scenarios.md, test-plan.md, and the `outbound_queue` table's own docstring. Narrows, but
does not flip, `release-checklist.md`'s failure-scenarios row (5 of 10 scenarios now genuinely
unverified, down from 9).

**Cross-cutting fix, [Sprint 51](sprint-51.md) (not a numbered item):** the "Schema version
mismatch after an update" failure scenario built the same way (`migration_test.dart`) — and found a
real, previously-undetected production bug in the process: `Migrator.createTable` builds a table
from its *current* Dart shape, not its historical one, so a table created in one `onUpgrade` step
and altered in a later one (`shop_settings_cache`, Sprint 37 + Sprint 39) broke with an unhandled
duplicate-column error for any device jumping both steps in one update — permanently losing access
to its own local database, including any unsynced sales. Fixed with a guarded `addColumn`; the
standing rule for future migrations documented in `schema-local.md`'s new "Schema-migration safety"
section. Narrows `release-checklist.md`'s failure-scenarios row further (4 of 10 scenarios now
genuinely unverified, down from 5).

**Cross-cutting fix, [Sprint 52](sprint-52.md) (not a numbered item):** the client half of
"Connectivity lost mid-batch" built the same way (`sync_repository_test.dart`) — the one row
test-plan.md had specifically said needed a live server + fault-injecting proxy, which it turned out
not to. Found a third instance of the same doc-vs-code gap Sprints 50/51 both found:
`failure-scenarios.md`'s "operations not yet acknowledged return to FailedRetrying" is not literally
what the code does — an unacknowledged row is simply left untouched, delivering the same practical
safety guarantee via a simpler mechanism. Corrected. Narrows `release-checklist.md`'s
failure-scenarios row again (3 of 10 scenarios now genuinely unverified, down from 4).

**Cross-cutting fix, [Sprint 53](sprint-53.md) (not a numbered item — founder-confirmed to build
storage-full handling, which led straight to a foundational gap first):** `inbound-sync.md §4`'s
`stock_movements` retention window (current + prior financial year) had been decided but never
implemented on either side — the server pull was unfiltered since Sprint 36, and nothing ever
pruned an already-pulled row locally. Both fixed: `stockMovementsRetentionCutoff` (server clock)
bounds the pull; `SyncRepository._pruneStaleStockMovements` (device clock, unconditional) prunes
the local cache after every sync. Two stale claims in `failure-scenarios.md §3` corrected in the
same pass: pruning was never threshold-gated in practice (now deliberately unconditional, decoupled
from the still-unbuilt disk-space-detection tier), and "cached product images" was never a real
feature to prune. This is the fourth consecutive sprint where checking a design claim directly
against the code found a real gap.

**Cross-cutting fix, [Sprint 54](sprint-54.md) (not a numbered item — founder-confirmed to build
storage-full handling, unlike Sprints 50–53 which were tests/fixes, not new product surface):**
`failure-scenarios.md §3`'s tier 3 (real disk-space detection + the designed low-storage warning)
built. `disk_space_2` chosen over the stale `disk_space`/`disk_space_plus` fork after checking
pub.dev directly (Sprint 48's own SQLCipher diligence, applied again); a 100 MB threshold and a
fail-open-on-probe-error choice, both stated as dated, correctable decisions rather than measured
answers. Storage-full is now the 6th of the 10 named failure scenarios with real automated
coverage — only "Token expired while queued" remains a genuinely unverified real gap, needing the
full local Supabase CLI stack this project doesn't have.

**Cross-cutting fix, [Sprint 55](sprint-55.md) (not a numbered item — server half only, closes
Sprint 43's OWASP finding for `authorisation-model.md §2`'s device-revocation step):** `devices`
table, `POST /auth/register-device`/`GET /devices`/`PATCH /devices/{id}/revoke`, and
`requireSession`'s per-request `devices.revoked_at` check via a new `X-Device-Id` header, all built
exactly as `schema-server.md`/`authentication.md`/`identity.md` already designed. Verified against
a real Postgres connection with the same RLS deliberate-break-and-fix rigor Sprint 40 established
(98/98 integration checks, `devices` added to the cross-tenant isolation suite as its 20th real
table). Found a genuine rollout risk before merging — this hard check would immediately reject
every request from any currently-installed mobile build until it also sends the new header —
confirmed with the founder that no live reliance on today's backend makes this safe; mobile wiring
is deliberately deferred to a follow-up sprint, not bundled in under time pressure.

**Cross-cutting fix, [Sprint 56](sprint-56.md) (not a numbered item — the mobile half of the same
gap, the deferred follow-up Sprint 55 named):** `client_device_id` generated once per install and
persisted locally (a new nullable column on the existing `device_identity` table, alongside the
invoice-numbering `shortId`), registered via `POST /auth/register-device` on sign-in and,
best-effort, on every launch with an existing session, sent as the `X-Device-Id` header on every
subsequent request, with a `DEVICE_REVOKED` response forcing an immediate local sign-out. Found and
fixed two real bugs surfaced by its own verification, not by inspection: a test-only historical
schema needed the new migration step undone too (the same "fresh onCreate schema doesn't match a
genuine historical shape" gap Sprint 51 first found); and a transient `register-device` failure was
letting `SignInController` report a successful sign-in as a failed one — now swallowed,
best-effort, matching `main.dart`'s own established pattern. 273/273 mobile tests (266 pre-existing
+ 7 new), `flutter analyze` clean.

**Cross-cutting fix, [Sprint 57](sprint-57.md) (not a numbered item):** "Token expired while
queued" — [failure-scenarios.md](../13-offline-sync/failure-scenarios.md)'s last unverified
scenario — built. Checked directly whether `test-plan.md`'s own "needs the full Supabase CLI stack"
excuse actually held, the same way Sprints 50–52 already checked three other such excuses and found
them false; it didn't hold here either. The real gap was that no reactive refresh-and-retry code
existed in the mobile client at all — `authentication.md §3` already implied it did. Built
`api_client.dart`'s missing `onError` interceptor (one `refreshSession()` call, one retry, on any
`401 UNAUTHENTICATED`); found and corrected `error-catalogue.md`'s `TOKEN_EXPIRED` code, which was
never actually implementable server-side. All 10 named failure scenarios now have real coverage or
are resolved-by-design/not-applicable — `release-checklist.md`'s failure-scenarios row flips to
satisfied for the first time in this project's history. 277/277 mobile tests (273 pre-existing + 4
new), `flutter analyze` clean.

**Cross-cutting fix, [Sprint 58](sprint-58.md) (not a numbered item, documentation-accuracy only —
no code change):** found Android release signing (`owasp-checklist.md`'s M8 finding, open since
Sprint 43) had never been threaded into `release-checklist.md`'s actual release gate at all — named
in one document's "4 real gaps remain" list for 15 sprints without ever reaching the other. Found a
second, compounding gap in the same pass: `cd-workflows.md §2`'s entire Android build→sign→upload
pipeline (`release-candidate.yml`) was never actually built — no such workflow exists, matching the
exact "designed but not built" gap Sprint 55/PR #79 already found for this same document's §1.
Corrected across `owasp-checklist.md`, `cd-workflows.md §2`, and `release-checklist.md` (now a new,
explicit pilot-ready row, not folded into the OWASP row it compounds). Also found and corrected a
self-introduced accounting error in `release-checklist.md`'s own Sprint 57 edit (M4's numbered
backlog items are 1–8 done, not "9... done" — item 9, MTS execution, is a founder action, never
counted as engineering). Release-checklist.md's pilot-ready gate now has three unresolved rows
(up from two), all founder-blocked or infra-blocked, none open engineering work.

**Cross-cutting fix, [Sprint 59](sprint-59.md) (not a numbered item, documentation-accuracy only —
no code change, but a genuinely severe finding):** checked `cd-workflows.md §1`'s own claim that
every RLS SQL file (`001`–`019`) was, in practice, eventually applied to the real production
database — citing `implementation-log.md`'s "applied live" entries as its evidence — file by file
against the actual documentary record, rather than trusted at face value. That confirming phrase
appears explicitly for only 7 of the 18 RLS files. For `017`/`018`
(`sale_line_items`/`sale_payments`/`return_line_items` — Sprint 40's own fix for the two tables that
had *zero* RLS at all) and `019` (`devices`, Sprint 55), **there is no confirmation anywhere on
record that these policies were ever actually applied to the real production database** — Sprint
40's own text explicitly distinguishes local verification from "the shared production Supabase
project" and never claims the latter for these two files; Sprint 55's own demo script lists a
real-Supabase smoke test as "not performed this sprint." This is a distinct, more severe
possibility than `owasp-checklist.md`'s existing FORCE/role finding — "the app works in production"
is equally consistent with "RLS present but owner-exempt" and "RLS never applied for these specific
tables," so it can't be used to rule the second explanation out. Corrected across
`owasp-checklist.md` (finding #1 grew a second dimension), `cd-workflows.md §1`, and
`release-checklist.md`'s OWASP row. This session cannot check the real production database
directly — confirming this for at minimum `017`/`018`/`019` is now the single most action-critical
item flagged to the founder, ahead of the FORCE/role question it's a precondition for.

**Cross-cutting fix, [Sprint 60](sprint-60.md) (not a numbered item, documentation-accuracy only —
no code change):** checked every milestone's own exit criterion against what was actually verified
when it was declared closed, the same discipline Sprints 58/59 applied to M4's release gate. Found
that [milestones.md](../16-milestones/milestones.md)'s **M2** row states a stricter exit criterion
than "all 6 backlog items done" (the basis §3 above actually closed on, Sprint 30) —
"the tap-count-audit.md budget... measured on the reference low-end device..., not estimated" — and
that criterion was never actually satisfied: the reference device has never been owned, unchanged
since Sprint 43's finding through today. M0 and M4, this project's other two milestones with a
hardware-dependent exit criterion, were each closed (or, for M4, deliberately left open) with an
honest, explicit caveat naming this exact gap; M2's closure carried none until now. Corrected in
`milestones.md` with a dated note under M2's row, and in §3 above — not by weakening "all 6 items
done" (still true) but by naming the real gap between that and this milestone's own stricter
exit-criteria text. M1 and M3's exit criteria were checked too and don't share this issue — neither
requires physical-hardware measurement.

**Cross-cutting fix, [Sprint 61](sprint-61.md) (not a numbered item, documentation-accuracy —
narrows rather than deepens a prior finding, the first of this kind in this run of sprints):**
read [pilot-plan.md](../16-milestones/pilot-plan.md) in full for the first time this session (it
hadn't been touched since Sprint 01/before any of M1–M4 was built) and found `release-checklist.md`'s
own Sprint 58 Android-distribution row had never been checked against it. That row required Google
Play Console's Internal Testing track for pilot readiness, following `cd-workflows.md §2`'s
Phase-15-era design — but `pilot-plan.md` (Phase 16, written later) already commits the *actual*
first pilot to something much smaller: 2–3 founder-known shops, founder physically present for
day-one, a deliberately minimal support model that names avoiding "premature generality" as its own
explicit standard. Standing up Play Console API access, a service account, and an automated release
pipeline for that pilot is exactly the generality `pilot-plan.md` already argues against elsewhere
(in-app feedback tooling). What the pilot actually needs — a real signing keystore, then a direct
sideload install during the founder's own visit, the identical mechanism already proven across
every real-device install this project has done — is narrower and shares its one remaining blocker
with the OWASP row's own Android-signing finding, not a second, independent one. Corrected
`cd-workflows.md §2`, `release-checklist.md` (narrowed the §2 row, moved the full CI/Play-Console
pipeline to §3 as commercial-launch scope), and `pilot-plan.md` itself (added the missing "how does
the app reach the device" step this document should have named all along). Net effect: the number
of distinct concerns blocking M4's pilot-ready closure drops from three to **two** (MTS execution;
the OWASP review's three findings) — the first correction in this run of sprints that shortened the
founder's remaining task list rather than lengthened it.

**Cross-cutting deliverable, [Sprint 62](sprint-62.md) (not a numbered item, not documentation
accuracy this time — a genuinely new artifact):** Sprint 59's own finding (no documentary
confirmation that `017`/`018`/`019` were ever applied to the real production database) and
`owasp-checklist.md`'s finding #1 (does the app's own role bypass RLS) both end the same way —
"this session cannot check the real production database directly." Rather than leave that as a
dead end, built the founder a direct answer:
[supabase/sql/diagnostics/check_rls_status.sql](../../supabase/sql/diagnostics/check_rls_status.sql)
— two read-only queries against `pg_tables`/`pg_roles`, safe to paste directly into the Supabase
Dashboard's SQL Editor for the production project, answering both open questions in one
five-minute paste-and-read action instead of leaving the founder to work out how to check either.
Not a migration, never applied by CI or automatically — placed in its own `diagnostics/`
subdirectory specifically so it can never be mistaken for one of the numbered policy files.
Referenced from `cd-workflows.md §1`, `owasp-checklist.md`'s finding #1, and
`release-checklist.md`'s OWASP row — the three places a reader following up on this finding would
actually look.

**Cross-cutting fix, [Sprint 63](sprint-63.md) (not a numbered item — closes the code half of
Sprint 43's own M8 finding):** `apps/mobile/android/app/build.gradle.kts` unconditionally signed
release builds with the debug keystore since M0. Wired the standard Flutter release-signing
pattern instead: real credentials read from a gitignored `key.properties` file if one exists
(`apps/mobile/android/key.properties.example` added, naming the exact `keytool` command and the
four values needed), falling back to the debug keystore, unchanged, when it doesn't — no behaviour
change until a real `key.properties` is actually created, verified with a clean
`flutter build apk --debug`. Closes the code side of `owasp-checklist.md`'s M8 finding entirely;
the founder's own remaining task narrows to running one command and filling in one file, not
writing any code. Corrected `cd-workflows.md §2`, `owasp-checklist.md`'s M8 row and summary, and
`release-checklist.md`'s Android row to match.

**Cross-cutting fix, [Sprint 64](sprint-64.md) (not a numbered item — real client-side defense-in-
depth found hiding inside a third "purely founder-blocked" finding):** re-examined Sprint 45's
sign-in rate-limiting finding the same way Sprints 62/63 re-examined RLS and Android signing.
The server-side claim ("sign-in never reaches an `apps/web` Route Handler") holds fully under
scrutiny — but nothing on the mobile client throttled repeated failed sign-in attempts either,
despite that being ordinary, safe engineering work independent of any Supabase setting. Built:
`SignInController` free-passes the first 3 failures, then applies an exponential cooldown (5s,
10s, 20s, 40s, capped at 60s) before the same app instance can retry, resetting on any success —
throttles one device's own retry loop, never an account across devices, an honestly-scoped
defense-in-depth layer, not a substitute for the still-open server-side gap. `flutter analyze`
clean, `flutter test` 280/280 (277 pre-existing + 3 new). Corrected `rate-limiting.md`,
`identity-and-sessions.md §6`, `owasp-checklist.md`'s A07 row and summary, and
`release-checklist.md`'s OWASP row to match.

## 6. Ordering rule, restated

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
| 0.23.0 | 2026-08-14 | Item 3 (Discount) done — [Sprint 27](sprint-27.md): per-line `discount_percent_basis_points`/`discount_amount_minor_units` (DR-011), `DISCOUNT_REQUIRES_APPROVAL` above threshold (DR-012) built and live-verified (17/17). Found and corrected a real gap in the same pass: `sales.subtotal_minor_units` silently meant "pre-discount raw sum," not money-and-tax.md's always-specified post-discount value. M2 now has items 4–6 remaining. |
| 0.24.0 | 2026-08-14 | Item 4 (Tax computation) done — [Sprint 28](sprint-28.md): `tax_total_minor_units`/`tax_registration_type_at_sale`/per-line `tax_rate_basis_points`/`tax_minor_units` built and live-verified (20/20), both exclusive and inclusive pricing modes. Found and resolved a real gap in money-and-tax.md's own worked examples in the same pass: inclusive pricing combined with a discount was never jointly specified. M2 now has items 5–6 remaining. |
| 0.25.0 | 2026-08-14 | Item 5 (Split Payment) done — [Sprint 29](sprint-29.md): `payments` loosened to one-or-more entries across `cash`/`card`/`other` (FR-028), `PAYMENT_AMOUNT_MISMATCH` restated as a sum check, built and live-verified (14/14). No schema change; Trading Day's `expected_cash_minor_units` aggregation confirmed live to already exclude card/other portions correctly. M2 now has item 6 remaining. |
| 0.26.0 | 2026-08-14 | Item 6 (Hold/Resume) done — [Sprint 30](sprint-30.md): mobile-only, `sales.status` transitions `draft`→`held`→`completed` on the client, built to navigation-model.md §4's fuller continuous-auto-persistence requirement, `flutter analyze`/`flutter test` 118/118. **M2 — Full POS Loop is now fully closed, all 6 items done.** |
| 0.27.0 | 2026-08-16 | M3 fully decomposed (5 items, 13.5 person-days) — Customers (server+mobile), Returns & Refund (server+mobile), conflict-resolution field-merge scoped to `customers`. Traced the `Customers → Returns` graph edge to WF-012's phone-lookup step, never previously explained. Two real gaps found while decomposing, not by writing code first: (1) the sync engine has never had a single `.update` operation type for any entity despite `categories`/`units`/`products`/`customers` being classified "Client-editable" since Phase 13 — item 5 is genuinely new sync-engine capability, deliberately scoped to `customers` only since no other client-editable entity has a mobile edit screen yet either; (2) `offline-workflows.md` Finding 1's on-paper resolution (`sync_rejections` table + Owner review flow, `failure-scenarios.md`) was never actually built — item 3 builds the underlying server-side re-validation correctness Returns' offline approval needs (DR-017/018), but the dedicated `sync_rejections` table/review screen is explicitly deferred, named rather than silently dropped, the same reasoned-deferral precedent Sprint 26 set with `TRADING_DAY_NOT_OPEN`. |
| 0.28.0 | 2026-08-16 | Item 1 (Customers, server) done — [Sprint 31](sprint-31.md): `customers` table, `sales.customer_id` (nullable), `POST`/`GET`/`PATCH`/`DELETE /customers`, `GET /customers/{id}/purchase-history` built and live-verified (12/12). Found and fixed a real bug live: a Zod `.refine()` returned the wrong error code (`VALIDATION_FAILED` instead of `CUSTOMER_IDENTIFIER_REQUIRED`), moved to the service layer. Corrected permission-matrix.md's missing edit/deactivate rows in the same pass. M3 now has items 2–5 remaining. |
| 0.29.0 | 2026-08-16 | Item 2 (Customers, mobile) done — [Sprint 32](sprint-32.md): `customer.create` sync-push type, `POST /sales` accepting an optional `customer_id`, and the mobile UI (`CustomerPickerSheet`, `/customers`, `/customers/:id`) all built and live-verified (9/9 server checks, 145/145 `flutter test`). `flutter analyze`/`tsc`/`eslint`/`vitest` all clean. M3 now has items 3–5 remaining. |
| 0.30.0 | 2026-08-16 | Item 3 (Returns & Refund, server) done — [Sprint 33](sprint-33.md): `returns`/`return_line_items` tables, `POST`/`GET /returns`/`GET /returns/{id}`/`GET /returns/approvals`/`POST /returns/{id}/approve`/`reject`, and `return.create`/`return.approve`/`return.reject` sync-push types all built and live-verified (22/22). Found and corrected two real schema gaps while writing the spec (`created_by`/`created_at` missing from schema-server.md's `returns` table; a redundant `client_operation_id` column dropped in favour of `id` alone). DR-014's per-unit-price rounding ambiguity resolved: exact-remaining-amount for a full-remaining-quantity return, proportional rounding only for a genuine partial. M3 now has items 4–5 remaining. |
| 0.31.0 | 2026-08-16 | Item 4 (Returns & Refund, mobile) done — [Sprint 34](sprint-34.md): `/returns/new`/`/returns/:id`/`/returns/approvals`, local `Returns`/`ReturnLineItems` tables, `return.create`/`return.approve`/`return.reject` written to `outbound_queue`, built and verified (176 mobile tests, 4/4 live server checks). Found and fixed a real, blocking gap before writing mobile code: `formatSale` never exposed a sale line item's own `id`, which `POST /returns` needs. Resolved the approvals-queue badge placement and WF-013's interrupt/queue split as dated decisions, both left open by Sprint 33's own text. M3 now has item 5 remaining. |
| 0.32.0 | 2026-08-16 | Item 5 (conflict-resolution field-merge) done — [Sprint 35](sprint-35.md): `customer.update` sync-push type, `PATCH /customers/{id}` upgraded to the merge-aware shape, `customer_field_conflicts`, `GET /customers/conflicts`/`POST /customers/conflicts/{id}/resolve`, mobile `CustomerEditScreen`/`ConflictsScreen`, all built and live-verified (18/18) — the exact worked-example scenario (two staff editing the same customer's phone number) provoked for real, end to end. Found and resolved a real gap while writing the spec: `base_updated_at` alone can't support a field-level 3-way merge (no server-side field history exists), resolved by having the client send each field's own base value too. **M3 — Customers & Returns is now fully closed, all 5 items done.** |
| 0.33.0 | 2026-08-16 | M4 fully decomposed (9 items, 19.5 person-days) — Sync pull reporting-parity extension, Reports (4 screens, local-only), Settings mobile UI, printer pairing + receipt template, cross-tenant isolation suite in CI, offline adversarial suite in CI, nightly pipeline, OWASP review against the real build, MTS-01/02/03 execution. Four real gaps found while decomposing, not by writing code first: (1) sync-api.md has named `stock_movements`/`sales` reporting-parity pull targets since Phase 11 with zero implementation — Reports is silently load-bearing on a capability that was never built (item 1); (2) Reports' Manager/Owner gate has no server call to enforce it against once item 1 lands, since the underlying data is already synced to every device regardless of role — named as a deliberate, narrow client-side-only exception to this project's usual server-enforcement stance, not an oversight; (3) milestones.md's M4 Scope line named the 10× load test, contradicting its own Exit criteria row's pilot-ready-only restriction — corrected there, no load-test item appears here; (4) checked the actual repository rather than trusting phase docs: `.github/workflows/` contains only `pr.yml` — no nightly pipeline, cross-tenant isolation suite, or offline adversarial harness exists anywhere despite full specification since Phase 12/13 (items 5–7). |
| 0.34.0 | 2026-08-16 | Item 1 (sync pull, reporting parity) done — [Sprint 36](sprint-36.md): `GET /sync/pull` gains `stock_movements`/`sales` entity types, live-verified (24/24). Found a real gap while implementing, not anticipated at decomposition time: a single `next_cursor` field can't mean both "keep paging now" and "durable resume point for next cycle" for an ever-growing entity type — resolved by adding a distinct `has_more` field for these two types (a dated correction to sync-api.md §6), plus a new local `sync_cursors` table so mobile can persist a per-entity-type resume cursor, unlike `products`' own deliberately-unchanged full-re-pull-every-cycle behaviour. M4 now has items 2–9 remaining. |
| 0.35.0 | 2026-08-16 | Item 2 (Reports) done — [Sprint 37](sprint-37.md): all four core reports built (daily sales, stock value, top products, low stock), entirely local Drift aggregation, no new server report endpoint. Two further real gaps found while starting it, not anticipated at decomposition time: no low-stock threshold configuration existed anywhere in this schema despite BR-024/BR-045 requiring one (added `shop_settings.low_stock_threshold_quantity`, a shop-wide default matching `tax_rate_basis_points`' own V1-simplification precedent, live-verified 11/11); `shop_settings` had never been synced to any device despite being documented as a pull entity type since Phase 11 (added as sync pull's 4th entity type, trivial — one row, never paginated). Built this codebase's first genuine client-side role-awareness to gate the Reports entry point (a cached, fail-closed probe against the already-existing `GET /users` endpoint, since no network call at report-view time exists to surface a `403` the way every other role-gated screen does). M4 now has items 3–9 remaining. |
| 0.36.0 | 2026-08-16 | Item 3 (Settings, mobile UI) done — [Sprint 38](sprint-38.md): `/settings` screen surfacing tax mode/rate/pricing mode/rounding rule/currency/low-stock threshold/auto-approval thresholds, no server change needed (already complete since Sprint 25). Built as Pattern B — reachable by every role, the server's own role-shaped `GET /settings` response and `403` on `PATCH` do the actual gating — the opposite of Reports' hide-entirely Pattern A, since this screen's `GET /settings` is itself a real, already role-shaping network call unlike Reports' pure-local data. Found a real spec-currency gap while updating the module spec: Sprint 37's `low_stock_threshold_quantity` had never been folded into `settings/specification.md`'s own Change Log, silently drifting from the service code for two days. `route-map.md` corrected in the same pass: `/settings`'s "Offline: Yes" overstated a cache this screen deliberately doesn't have, and `/settings/tax`/`/settings/currency` are consolidated into one screen rather than built as separate routes. 227 mobile tests (were 218). **M4 now has items 4–9 remaining.** |
| 0.37.0 | 2026-08-17 | Item 4 (Settings, printer pairing + receipt template) done — [Sprint 39](sprint-39.md): `/settings/printer` (pairing + test-print) and `/settings/receipt-template` (footer-message editor) built. Two corrections to this item's own original framing, found while writing the spec: `receipt_template_config` becomes `PATCH`-able but with exactly one field, `footer_message` — `RECEIPT_TEMPLATE_MISSING_MANDATORY_FIELD` stays deliberately unreachable this sprint too, since GSTIN (the only real conditional-mandatory-field candidate) isn't captured in `shop_settings` at all, a separate, larger prerequisite gap; `printer_config` stays untouched — "which printer is paired" is per-device data with no `devices` table to belong to server-side, resolved entirely client-side in a new local-only `PairedPrinterCache` instead. `ShopSettingsCache` extended with a third field (`footerMessage`) so printing stays fully offline per FR-077/FR-078. Live-verified 7/7; 239 mobile tests (were 227), 209 web tests (were 207). **M4 now has items 5–9 remaining.** |
| 0.38.0 | 2026-08-18 | Item 5 (cross-tenant isolation suite, CI-enforced) done — [Sprint 40](sprint-40.md): `.github/workflows/pr.yml` gains a new `fast-integration` job — a fresh `postgres:15` container per run, migrations + all RLS policies applied, then an automated negative-test suite (read/update/delete-by-ID, all 19 real tables) authenticated as a real Postgres `authenticated` role via `SET LOCAL request.jwt.claims`, the same mechanism a real Supabase JWT drives. Three real gaps found and closed, not by inspection: the "22 tables" figure itself had drifted from the built schema (corrected to 19 — tenant-isolation.md §2's own dated note has the breakdown); `sale_line_items`/`sale_payments`/`return_line_items` had **no RLS at all**, contradicting the schema's own design template — closed via two new migration files, verified by deliberately breaking RLS on one table and confirming the suite catches it; ci-pipeline.md/security-test-plan.md/ci-workflows.md's own CI-placement wording had drifted apart ("every migration" vs. "every PR") — reconciled to what was actually built. Realtime extension (tenant-isolation.md §4) deliberately deferred — needs the full local Supabase CLI stack, a materially larger scope — named, not silently dropped. 76/76 integration checks pass; 209 web unit tests unaffected (fully separate suite/config). **M4 now has items 6–9 remaining.** |
| 0.39.0 | 2026-08-19 | Item 6 (offline adversarial suite, CI-enforced) done — [Sprint 41](sprint-41.md): idempotent-replay (3/3 cases), concurrent-composition non-fuzzed (4/4 cases), and 1 server-testable failure scenario added to the same `fast-integration` job Sprint 40 built, no new CI infra — replay/order-independence proved server-observable, no toxiproxy needed for this subset. N-device fuzzed composition (100 runs) written and locally confirmed (100/100 passing, ~90s), nightly-gated, ready for item 7. Found and fixed a real, previously-unverified concurrency gap: `sale.create`/`return.create`/`return.approve`'s replay-safety check was a read-then-write race under genuine concurrent requests (not sequential replay) — the first test in this project's history to exercise real overlapping requests against the same row, not one at a time. Found `seedTenant` (Sprint 40) never exposed the seeded user's `authUserId`, making it unusable for any test calling application service code — fixed additively. Found `test-plan.md §3`'s "one test per row" (10 named failure scenarios) conflated three different test venues (server / mobile-only / needs the full Supabase CLI stack / already-proven-no-test-needed) — reclassified; only 1 row was actually buildable here. 84/84 integration checks pass (76 cross-tenant + 8 new); 209 web unit tests unaffected. **M4 now has items 7–9 remaining.** |
| 0.40.0 | 2026-08-19 | Item 7 (nightly CI pipeline) done — [Sprint 42](sprint-42.md): new `.github/workflows/nightly.yml` (N-device fuzzed composition, 100 runs, the only nightly-deferred content items 5/6 actually produced) plus `.github/dependabot.yml` (npm/pub/github-actions, weekly). Found item 5 has no distinct slow subset ready at all (its one deferred piece, the Realtime extension, needs the full Supabase CLI stack); found `ci-pipeline.md §3`'s "full failure-scenario suite"/"extended property-based tests" rows have no code to run on any tier — the former because Sprint 41 already found only 1 of 10 scenarios is server-testable, the latter because no property-based suite was ever built despite `test-strategy.md §1` claiming DR-008/DR-013 coverage from it (corrected to the real unit-test coverage that does exist). No `release-candidate.yml` exists to gate on a nightly failure, so built a standing-GitHub-issue-on-failure mechanism instead; found `type:defect`/`priority:P0` labels (project-board.md §3) were never actually created in the repo, substituted the stock `bug` label. `tsc`/`eslint`/`vitest`/production build all clean. **M4 now has items 8–9 remaining.** |
| 0.41.0 | 2026-08-19 | Item 8 (OWASP checklist review against the real build) done — [Sprint 43](sprint-43.md): every one of `owasp-checklist.md`'s 20 rows re-verified against real code, not the design docs it cited. **The single most significant finding of this project so far**: row-level security is very likely inert for all real production API traffic — no `FORCE ROW LEVEL SECURITY` exists anywhere, and no code ever sets `request.jwt.claims` on the app's own database connection, so the "defence in depth" second layer `tenant-isolation.md`/`tenancy-model.md` have claimed since Phase 07/12 may not actually protect anything beyond the API's own tenant-scoping logic — flagged for the founder, deliberately not fixed, since a wrong change risks a full production outage. Also found rate limiting is entirely unimplemented despite `identity-and-sessions.md §6` claiming it. Fixed in the same pass: missing `next.config.ts` security headers, and a real DR-025 audit-log-coverage gap (3 of 4 `stock_movements` types plus settings changes had no paired `audit_log` entry at all) — first self-identified in Sprint 12's own implementation-log entry and never subsequently closed across 15 sprints, closed now across 5 repository functions, verified against a real database. Four further real gaps named, not fixed (mobile session storage falls back to plaintext, the local Drift database is unencrypted, customer-erasure anonymisation is designed but unbuilt, the Android release build signs with the debug keystore — founder-blocked). `tsc`/`eslint`/`vitest`/production build all clean. **M4 now has item 9 remaining.** |
| 0.42.0 | 2026-08-19 | Cross-cutting closeout, Sprint 44 (not a numbered M4 item): `release-checklist.md §2`, M4's own actual exit criterion, checked against Sprints 40–43's real results for the first time — two stale rows corrected (22 tables/Realtime → 19 tables, Realtime out of pilot scope; "all 10 failure scenarios" → "server-testable failure scenarios," since 9 of 10 have zero verification of any kind on record); the OWASP row's wording tightened so unresolved critical findings can't silently satisfy it. Honest conclusion recorded: this product is not pilot-ready today — four checklist rows unresolved, three newly surfaced by this pass. |
| 0.43.0 | 2026-08-19 | Cross-cutting fix, Sprint 45 (not a numbered M4 item): rate limiting built for the 3 endpoint classes reachable from this codebase (mutating/read/sync-push — Postgres-backed fixed-window counter, `requirePermission`, no external service), closing item 8's finding #2. Found the Auth class is architecturally unreachable from this codebase at all (sign-in never touches an `apps/web` Route Handler) — a real, named gap, not fixed, needing a Supabase-side configuration check. Found and corrected a real 500-vs-200 sync-push-batch-cap drift in `rate-limiting.md`. 90/90 integration checks, 211/211 unit tests, `tsc`/`eslint` clean. |
| 0.44.0 | 2026-08-19 | Cross-cutting fix, Sprint 46 (not a numbered M4 item): customer-erasure anonymisation built (`POST /customers/{id}/erase`, Owner only), closing item 8's finding M6 — `privacy.md §4`'s design, fully specified since Phase 12, had zero implementation. Nulls `name`/`phone`, sets a new `erased_at` marker, preserves an existing `deactivated_at` rather than overwriting it. Found and fixed a related gap: `deactivated_at` had never been exposed in any customer API response at all. 94/94 integration checks, 215/215 unit tests, `tsc`/`eslint` clean. |
| 0.45.0 | 2026-08-19 | Cross-cutting fix, Sprint 47 (not a numbered M4 item): mobile secure token storage built (`SecureLocalStorage`, `flutter_secure_storage`-backed), closing item 8's finding M1 — the session had been sitting in plaintext `SharedPreferences` on Android despite `flutter_secure_storage` already being a dependency. No migration from the old plaintext value. Found and fixed a deprecated `flutter_secure_storage` config option via `flutter analyze`. 244/244 mobile tests (239 pre-existing + 5 new), `flutter analyze` clean. |
| 0.46.0 | 2026-08-19 | Cross-cutting fix, Sprint 48 (not a numbered M4 item): on-device database encryption built (SQLCipher via `package:sqlite3` 3.x's native-hooks mechanism, `AppDatabase.encrypted`), closing item 8's finding M9 — the local database had been plain, unencrypted SQLite despite `data-protection.md §3` deciding on SQLCipher since Phase 12. Found the anticipated `sqlcipher_flutter_libs` plugin is now a no-op stub; the real integration is a `pubspec.yaml` hook declaration instead. A legacy plaintext database file is reset once on first launch after upgrade rather than migrated, unlike Sprints 46/47's trivially-reset data. Verified against a real Android debug build (`libsqlcipher.so` confirmed bundled) and a dedicated unkeyed-read-fails test. 252/252 mobile tests (244 pre-existing + 8 new), `flutter analyze` clean. |
| 0.47.0 | 2026-08-19 | Cross-cutting closeout, Sprint 49 (not a numbered M4 item): `release-checklist.md §2` re-checked against Sprints 45–48's real results. Nightly-suite row flips to satisfied — `nightly.yml` confirmed genuinely fired on its own `schedule` trigger and passed, via `gh run list`, not assumed. OWASP row's stale "rate limiting unimplemented" wording corrected to the narrower, accurate sign-in-specific architectural gap now that general rate limiting is built (Sprint 45). RLS and the 9 unverified failure scenarios re-confirmed unchanged. Bottom line: still not pilot-ready today, now three unresolved rows instead of four. No code changes. |
| 0.48.0 | 2026-08-19 | Cross-cutting fix, Sprint 50 (not a numbered M4 item, not a re-opening of item 6): "App killed mid-sync"/"Device rebooted with a full queue" failure scenarios built with existing `flutter test` infrastructure alone. Found and corrected a real doc/code gap: the mobile client never writes the `Syncing` transitional status state-machines.md specifies — corrected there, in failure-scenarios.md, test-plan.md, and the `outbound_queue` table's docstring. Narrows (does not flip) release-checklist.md's failure-scenarios row: 5 of 10 scenarios remain genuinely unverified, down from 9. 254/254 mobile tests (252 pre-existing + 2 new), `flutter analyze` clean. |
| 0.49.0 | 2026-08-20 | Cross-cutting fix, Sprint 51 (not a numbered M4 item): "Schema version mismatch after an update" built the same way (`migration_test.dart`, this project's first migration test) — and found a real, previously-undetected production bug: a table created in one `onUpgrade` step and altered in a later one broke with an unhandled duplicate-column error for any device jumping both steps in one update, permanently losing access to its own local database. Fixed with a guarded `addColumn`; standing rule for future migrations documented in schema-local.md. Narrows release-checklist.md's failure-scenarios row further: 4 of 10 scenarios remain genuinely unverified, down from 5. 256/256 mobile tests (254 pre-existing + 2 new), `flutter analyze` clean. |
| 0.50.0 | 2026-08-20 | Cross-cutting fix, Sprint 52 (not a numbered M4 item): the client half of "Connectivity lost mid-batch" built (`sync_repository_test.dart`) — the one row test-plan.md had specifically said needed a live server + fault-injecting proxy, found not to. Third instance of the same doc-vs-code gap Sprints 50/51 found: failure-scenarios.md's "return to FailedRetrying" is not literally what the code does. Corrected. Narrows release-checklist.md's failure-scenarios row further: 3 of 10 scenarios remain genuinely unverified, down from 4. 258/258 mobile tests (256 pre-existing + 2 new), `flutter analyze` clean. |
| 0.51.0 | 2026-08-20 | Cross-cutting fix, Sprint 53 (not a numbered M4 item, founder-confirmed to build storage-full handling): found tier 1 (proactive pruning) was never actually built — inbound-sync.md §4's stock_movements retention window (current + prior financial year) was decided but the server pull stayed unfiltered since Sprint 36 and nothing ever pruned the local cache. Both fixed: `stockMovementsRetentionCutoff` bounds the server pull (server clock); `_pruneStaleStockMovements` prunes the local cache every sync (device clock, unconditional, a deliberate simplification over the originally-implied threshold-gating). Corrected a second stale claim: "cached product images" was never a real feature. Tier 3 (disk-space detection, warning UI) remains real, separately-scoped future work. 218/218 web unit tests (215 pre-existing + 3 new), 260/260 mobile tests (258 pre-existing + 2 new), `tsc`/`eslint`/`flutter analyze` all clean. |
| 0.52.0 | 2026-08-20 | Cross-cutting fix, Sprint 54 (not a numbered M4 item, founder-confirmed): tier 3 built — `disk_space_2`-backed free-disk-space detection (100 MB threshold, fails open on a probe error), the designed low-storage warning shown persistently on `HomeScreen`. Package chosen after checking pub.dev directly (Sprint 48's own SQLCipher diligence). Storage-full is now the 6th of 10 named failure scenarios with real coverage; only "Token expired while queued" remains. 266/266 mobile tests (260 pre-existing + 6 new), `flutter analyze` clean, real Android debug build confirmed. |
| 0.53.0 | 2026-08-20 | Cross-cutting fix, Sprint 55 (not a numbered M4 item, server half only): device registration/revocation built — `devices` table, `POST /auth/register-device`/`GET /devices`/`PATCH /devices/{id}/revoke`, `requireSession`'s per-request check via a new `X-Device-Id` header. Closes Sprint 43's OWASP finding for `authorisation-model.md §2`. Verified against a real Postgres connection (98/98 integration checks including the RLS deliberate-break-and-fix cycle; `devices` is the isolation suite's 20th table). Found a real rollout risk before merging (would reject every currently-installed mobile build's requests) — confirmed with the founder that no live reliance makes this safe now; mobile wiring deferred to a follow-up sprint. 227/227 web unit tests (218 pre-existing + 9 new), `tsc`/`eslint` clean. |
| 0.54.0 | 2026-08-20 | Cross-cutting fix, Sprint 56 (not a numbered M4 item, mobile half of Sprint 55's same gap): `client_device_id` generated/persisted locally, registered on sign-in and on launch (best-effort), sent as `X-Device-Id` on every request, `DEVICE_REVOKED` forces local sign-out. Found and fixed two real bugs: a migration test's reconstructed historical schema needed updating for the new column (same class of gap Sprint 51 found), and a transient register-device failure was wrongly surfacing a successful sign-in as failed — now swallowed, best-effort. 273/273 mobile tests (266 pre-existing + 7 new), `flutter analyze` clean. |
| 0.55.0 | 2026-08-21 | Cross-cutting fix, Sprint 57 (not a numbered M4 item): "Token expired while queued" — the last unverified failure scenario — built. Checked test-plan.md's own "needs the full Supabase CLI stack" claim directly (the fifth such check in this project, after Sprints 50/51/52/54) and found it false again: the real gap was no reactive refresh-and-retry code existing in the mobile client at all, despite authentication.md §3 implying it did. Built `api_client.dart`'s missing `onError` interceptor (refresh once, retry once, on `401 UNAUTHENTICATED`); found and corrected `error-catalogue.md`'s `TOKEN_EXPIRED` code, never actually implementable server-side. All 10 named failure scenarios now covered — `release-checklist.md`'s failure-scenarios row flips to satisfied for the first time. 277/277 mobile tests (273 pre-existing + 4 new), `flutter analyze` clean. |
| 0.56.0 | 2026-08-21 | Cross-cutting fix, Sprint 58 (not a numbered M4 item, documentation-accuracy only): found Android release signing (owasp-checklist.md's M8 finding, open since Sprint 43) had never been threaded into release-checklist.md's actual release gate — named in one document for 15 sprints without ever reaching the other. Found a second, compounding gap: cd-workflows.md §2's entire Android build→sign→upload pipeline (`release-candidate.yml`) was never actually built, the same "designed but not built" class of gap Sprint 55/PR #79 already found for this document's §1. Corrected across all three documents; also corrected a self-introduced accounting error in the prior sprint's own release-checklist.md edit (M4 items 1–8 done, not "9," per item 9's own standing founder-blocked status). No code change. |
| 0.57.0 | 2026-08-21 | Cross-cutting fix, Sprint 59 (not a numbered M4 item, documentation-accuracy only, genuinely severe finding): checked cd-workflows.md §1's claim that every RLS SQL file was eventually applied to production, file by file, rather than trusted. The confirming "applied live" phrase appears explicitly for only 7 of 18 RLS files. For `017`/`018` (sale_line_items/sale_payments/return_line_items, Sprint 40's own zero-RLS fix) and `019` (devices, Sprint 55), no confirmation exists on record that these were ever applied to the real production database — a distinct, more severe possibility than owasp-checklist.md's existing FORCE/role finding, since "the app works in production" can't distinguish the two explanations. Corrected across owasp-checklist.md, cd-workflows.md §1, and release-checklist.md's OWASP row. Flagged to the founder as the single most action-critical item outstanding — genuinely unknown, not merely blocked. No code change. |
| 0.58.0 | 2026-08-21 | Cross-cutting fix, Sprint 60 (not a numbered M4 item, documentation-accuracy only): checked every milestone's own exit criterion against what was actually verified at closure. Found milestones.md's M2 row requires the tap-count-audit.md budget "measured on the reference low-end device..., not estimated" — never actually satisfied, since that device has never been owned (unchanged since Sprint 43), and M2's own closure (§3 above, Sprint 30) carried no caveat against this, unlike M0's and M4's honest treatment of their own hardware-dependent exit criteria. Corrected in milestones.md and §3 above with a dated note; M1/M3 checked and confirmed not to share this issue. No code change. |
| 0.59.0 | 2026-08-21 | Cross-cutting fix, Sprint 61 (not a numbered M4 item, documentation-accuracy — narrows a prior finding rather than deepening one): read pilot-plan.md in full for the first time and found release-checklist.md's Sprint 58 Android-distribution row had never been checked against it. Play Console Internal Testing was never actually required for pilot-plan.md's real pilot shape (2-3 founder-visited shops, deliberately minimal) — only a real signing keystore plus direct sideload is, the mechanism already proven across every real-device install this project has done. Corrected cd-workflows.md §2, release-checklist.md (narrowed §2's row, moved the full pipeline to §3/commercial scope), and pilot-plan.md itself (added the missing device-install step). Distinct blocking concerns for M4's pilot-ready closure drop from three to two. No code change. |
| 0.60.0 | 2026-08-21 | Cross-cutting deliverable, Sprint 62 (not a numbered M4 item — a new artifact, not a documentation correction): built `supabase/sql/diagnostics/check_rls_status.sql`, a read-only diagnostic the founder can paste into the Supabase Dashboard's SQL Editor to answer both Sprint 59's RLS-application question and owasp-checklist.md's FORCE/role question directly against the real production database. Referenced from cd-workflows.md §1, owasp-checklist.md's finding #1, and release-checklist.md's OWASP row. |
| 0.61.0 | 2026-08-21 | Cross-cutting fix, Sprint 63 (not a numbered M4 item, closes the code half of Sprint 43's M8 finding): wired build.gradle.kts to read real signing credentials from a gitignored key.properties if present, falling back to the debug keystore unchanged otherwise — the standard Flutter pattern, key.properties.example added with exact keytool instructions. Verified with a clean flutter build apk --debug. Corrected cd-workflows.md, owasp-checklist.md, and release-checklist.md — the founder's remaining Android-signing task is now purely running one command, no code work left. |
| 0.62.0 | 2026-08-21 | Cross-cutting fix, Sprint 64 (not a numbered M4 item, real client-side defense-in-depth found hiding inside a third "purely founder-blocked" finding): re-examined Sprint 45's sign-in rate-limiting finding and found the mobile client did nothing to throttle repeated failed attempts. Built SignInController's exponential-cooldown attempt throttling (5s-60s, resets on success), honestly scoped as one-device defense-in-depth, not a substitute for the still-open server-side gap. flutter test 280/280 (277 pre-existing + 3 new). Corrected rate-limiting.md, identity-and-sessions.md, owasp-checklist.md, and release-checklist.md. |
