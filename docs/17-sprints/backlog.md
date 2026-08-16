# Backlog

> **Status:** 🔵 In review
> **Phase:** 17 — Sprint Planning
> **Version:** 0.33.0
> **Last updated:** 2026-08-16
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
| 1 | Sync pull, reporting parity: `GET /sync/pull` gains `stock_movements` and `sales` entity types (this device's own local `sale_line_items` included in each pulled sale's payload, matching `GET /sales/{id}`'s existing shape), pulled from every device in the tenant/store, not just the calling device's own; mobile upsert-by-id into the existing local `stock_movements`/`sales` tables, deduplicated against rows the device itself already wrote locally (same id, no-op) — the real gap named above | — | 2.5 |
| 2 | Reports (mobile, local aggregation only, Manager/Owner client-side gate): daily sales total + trailing 7 days (FR-071), stock value = Σ(derived balance × price basis) (FR-072), products ranked by qty/value over a selected date range (FR-073), low-stock list sorted by distance below threshold (FR-074) — four screens computed entirely from the local Drift DB now populated by item 1, no new server endpoint (§ above) | 1 | 3 |
| 3 | Settings, mobile UI: `/settings` route (Owner-edit, Manager/Cashier read-only per the already-built role-shaped `GET /settings` response) surfacing tax mode/rate/pricing mode/rounding rule/currency — the first mobile screen to actually read or write any of these fields, which have been server-complete since Sprint 25 but never had a UI | — | 1.5 |
| 4 | Settings, printer pairing + receipt template (FR-077/FR-078): `PATCH /settings` stops rejecting `printer_config`/`receipt_template_config` outright, `RECEIPT_TEMPLATE_MISSING_MANDATORY_FIELD` becomes live-reachable for the first time (a mandatory-field list fixed in code, per [receipt-design.md](../10-design-system/receipt-design.md)); mobile pairing + test-print flow reusing Sprint 15's existing Bluetooth ESC/POS transport, and a receipt-template editor for non-mandatory fields only | 3 | 2.5 |
| 5 | Cross-tenant isolation suite, CI-enforced: automated negative tests against a real authenticated connection (not API-code inspection) for all 22 tables per [tenant-isolation.md §2](../12-security/tenant-isolation.md#2-what-every-table-means-precisely-restated-as-a-checklist)'s four categories, plus the Realtime-channel extension (§4) — wired into `pr.yml` as a blocking stage per [ci-pipeline.md §2](../14-testing/ci-pipeline.md#2-pipeline-stages--every-pull-request) | — | 3 |
| 6 | Offline adversarial suite in CI: toxiproxy (or equivalent) fault-injecting harness per [offline-test-suite.md §2](../14-testing/offline-test-suite.md#2-harness); idempotent-replay + 2-device composition as a fast `pr.yml`-blocking stage; N-device fuzzed composition (100 runs) and all 10 named failure scenarios ([failure-scenarios.md](../13-offline-sync/failure-scenarios.md)) as the slower, nightly-gated subset | — | 4 |
| 7 | Nightly CI pipeline: new `.github/workflows/nightly.yml` wiring items 5/6's slow subsets, plus Dependabot-based dependency audit ([ci-pipeline.md §3](../14-testing/ci-pipeline.md#3-nightly-pipeline)) — release-candidate-blocking, not same-day-merge-blocking, per that document's own rule | 5, 6 | 1 |
| 8 | OWASP checklist review against the actual release build: walk [owasp-checklist.md](../12-security/owasp-checklist.md)'s already-complete design-time traceability table against the real, running M0–M4 codebase (not the design docs it cites), confirming each mitigation is actually present in code, not just specified on paper | 1–7 | 1 |
| 9 | MTS-01/02/03 executed and evidenced: scripts already fully written in [manual-test-scripts.md](../14-testing/manual-test-scripts.md); execution itself is a founder action blocked on physical printer hardware (MTS-01) and the reference low-end device (MTS-03) per [device-matrix.md §3](../14-testing/device-matrix.md#3-this-is-a-founder-action-not-an-engineering-one--stated-plainly) — the same named, non-blocking-until-it-blocks shape M0's own item 11 established for exactly this kind of gap | 1–8 | 1 |

**Total: 19.5 person-days.** Items 5, 6, and 9 are the ones most likely to reveal further real gaps
once actually attempted — no CI-enforced isolation or adversarial-sync suite has ever been run
against this codebase before, and item 9 remains genuinely blocked on hardware the founder does not
yet own, tracked the same way M0's own physical-print step was.

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
