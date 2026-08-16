# SmartPOS X — Documentation

> **The Complete Mobile First Business Management Platform.**

This folder is the **single source of truth** for SmartPOS X. Code follows documentation, never
the reverse. If code and documentation disagree, that is a defect in one of them and it is fixed
in the same pull request.

---

## How to use this documentation

| If you want to… | Read |
| --- | --- |
| Understand what we are building and why | [01 — Project Vision](01-vision/) |
| Understand how we work and what "done" means | [00 — Governance](00-governance/) |
| Understand why a technical choice was made | [Architecture Decision Records](adr/) |
| Look up a term | [Glossary](GLOSSARY.md) |
| See what is built and what is not | [Module Registry](modules/) |

---

## Phase map

Phases run in order. **No phase is skipped.** A phase is not started until the previous phase is
approved. Each phase folder contains a `README.md` charter defining its objective, inputs,
deliverables and exit criteria.

| # | Phase | Folder | Status |
| --- | --- | --- | --- |
| 01 | Project Vision | [01-vision](01-vision/) | 🟢 Approved (OD-01 launch market provisional — see [open-decisions.md](01-vision/open-decisions.md)) |
| 02 | Business Requirements | [02-business-requirements](02-business-requirements/) | 🔵 In review — 54 BRs drafted; blocked from 🟢 only by GST-practitioner review and OD-01 confirmation |
| 03 | Functional Requirements | [03-functional-requirements](03-functional-requirements/) | 🔵 In review — 84 FRs, 26 NFRs, 26 domain rules, 28 user stories drafted |
| 04 | Software Requirement Specification | [04-srs](04-srs/) | 🔵 In review — SRS, system context (7 trust boundaries), constraints, quality attributes, dependencies all drafted |
| 05 | User Personas | [05-personas](05-personas/) | 🟡 Draft — hard-blocked on real shop interviews, not just research (see phase notes) |
| 06 | Business Workflows | [06-workflows](06-workflows/) | 🔵 In review — 13 V1 workflows, 4 exhaustive state machines, 3 findings flagged for Phase 13 |
| 07 | Database Design | [07-database](07-database/) | 🔵 In review — 22 tables, 6 ADRs accepted, stock-ledger correctness proven on paper |
| 08 | Folder Structure | [08-folder-structure](08-folder-structure/) | 🔵 In review — layering rules, CI-enforced, both apps mapped to Phase 07's schema |
| 09 | Navigation | [09-navigation](09-navigation/) | 🔵 In review — 42 routes mapped, tap-count audit found and fixed 1 over-budget workflow |
| 10 | Design System | [10-design-system](10-design-system/) | 🔵 In review — contrast proven by measurement in both themes; 3-screen composition proof; physical printer/device testing flagged pending for Phase 14/18 |
| 11 | API Design | [11-api](11-api/) | 🔵 In review — full contract for 7 modules + sync/realtime; 7 of 8 exit criteria met, 10× load test tracked to Phase 14/16 |
| 12 | Security Design | [12-security](12-security/) | 🔵 In review — full STRIDE across 8 boundaries, 22-table tenant-isolation checklist, cross-tenant proof extended to Realtime |
| 13 | Offline Synchronisation | [13-offline-sync](13-offline-sync/) | 🔵 In review — idempotent-replay and concurrent-composition proofs; all 10 failure scenarios resolved; all 3 standing cross-phase gaps (Finding 1, Realtime-outage, storage-full) closed |
| 14 | Testing Strategy | [14-testing](14-testing/) | 🔵 In review — full 26-rule test traceability; 3-tier CI pipeline; found and fixed a DR-025 audit-logging gap from Phase 12 |
| 15 | GitHub Project | [15-github-project](15-github-project/) | 🔵 In review — branch protection, 3-tier CI/CD workflows, full DoD-enforcing PR template; rollback rehearsal tracked to Phase 18 |
| 16 | Milestones | [16-milestones](16-milestones/) | 🔵 In review — all 5 deliverables complete; OD-06 resolved (solo, 10–20 hrs/week); V1 converts to ~10–15 months at the midpoint pace |
| 17 | Sprint Planning | [17-sprints](17-sprints/) | 🔵 In review — 2-week solo-sized cadence; M0 fully decomposed (21 person-days); M1 fully decomposed 2026-08-14 (8 items, 15.5 person-days) and **fully closed**; M2 fully decomposed 2026-08-14 (6 items, 12 person-days) and **fully closed**; M3 fully decomposed 2026-08-16 (5 items, 13.5 person-days) and **fully closed**; Sprint 01 through Sprint 35 all closed |
| 18 | Implementation | [18-implementation](18-implementation/) | 🟡 In progress — Sprints 01–15 built the full M0 walking skeleton (Identity/Auth through Bluetooth receipt printing), each closing a real gap first before writing code; Sprint 16 ran M0's own end-to-end proof for real on the founder's device — steps 1–7 (sign in, add a product, sell offline, reconnect, sync) confirmed working, no bug found, with only the physical-print step left open pending printer hardware the founder doesn't yet own; the founder then directed M1 to begin regardless (modules/README.md Rule 2's third exception); Sprint 17/18 built the first two M1 modules (Categories and Units), Sprint 19 extended Products with `category_id`/`unit_id`/`sku`/`barcode`/`hsn_sac_code` (optional, not required), Sprint 20 built the mobile catalogue UI (first local schema migration; category/unit creation found to be online-only), Sprint 21 built `GET /api/v1/products` plus the till's own barcode-scan/search/category-filter (all local, per FR-034/FR-036's "Fully offline" classification) — fixing a second real gap along the way, a Sprint 20 sync-pull mapping that never carried category/unit/sku/barcode down to devices — Sprint 22 built the `adjustment` stock-movement type plus the public `stock-movements`/`stock-balance` endpoints, finding that the create endpoint should exclude `movement_type: 'opening'` entirely rather than the originally-documented "accept it" contract, since every product already gets one automatically at creation, Sprint 23 built Roles & Permissions in full — `user_store_roles`, `GET/POST/PATCH/DELETE /users*`, `GET /audit-log`, and permission enforcement retrofitted across every endpoint built so far — closing three real gaps along the way (onboarding never assigned a role, `GET /audit-log` was named as a retrofit target but never built, and `POST /users/invite`'s original mechanism was underspecified, resolved via Supabase Admin's synchronous identity creation), and Sprint 24 closed M1 in full — canonical invoice numbers (an atomic per-tenant-per-financial-year counter, ADR-0008) and `GET /sales/{id}`/`GET /sales`/`GET /sales/lookup`, applying Sprint 23's own routing lesson proactively; GST invoice fields remain named, deferred M2 scope, since no tax computation exists yet. **M1 — Full Catalogue & Inventory, Multi-Role is fully built, all 8 backlog items done.** Sprint 25 opened **M2 — Full POS Loop** with its first item, Settings — `shop_settings` (tax mode/rate, pricing mode, rounding rule, auto-approval thresholds), a default row now written at onboarding, `GET`/`PATCH /api/v1/settings` role-shaped and optimistically-concurrent — closing two real gaps found while decomposing M2 itself: no `shop_settings` row was ever created anywhere in code, and neither schema-server.md nor money-and-tax.md ever named where the tax rate actually comes from (resolved as a dated Phase 07 correction, a single shop-wide flat rate). Sprint 26 built M2 item 2, Cash Drawer / Trading Day — `trading_days`, `POST /trading-days/open`/`{id}/close`/`{id}/reopen`, `GET /trading-days/current`, scoped per-store rather than per-device (no `devices` table exists) or per-user (this item's own pre-sprint guess), reasoned instead from offline-workflows.md's own already-recorded Finding 2 text; built the reopen endpoint, closing a real gap sales.md never listed despite state-machines.md/audit-model.md already specifying it; deliberately deferred `POST /sales`'s `TRADING_DAY_NOT_OPEN` hard gate, reversing this item's own pre-sprint plan, to avoid regressing the one live, working end-to-end sale flow this project has ahead of the matching mobile till change. Sprint 27 built M2 item 3, Discount — per-line `discount_percent_basis_points`/`discount_amount_minor_units` (DR-011), `DISCOUNT_REQUIRES_APPROVAL` above threshold (DR-012) satisfied by the caller's own Manager/Owner role or a named `discount_approved_by`, resolved fresh at request time per the same integrity model Finding 1 already established for offline approvals; found and corrected a real gap in the same pass — `sales.subtotal_minor_units` had silently meant "pre-discount raw sum" since M0, not money-and-tax.md's always-specified post-discount value, invisible until Discount existed to make the two diverge. Sprint 28 built M2 item 4, Tax computation — `tax_total_minor_units`/`tax_registration_type_at_sale`/per-line `tax_rate_basis_points`/`tax_minor_units`, wired entirely from `shop_settings` (no new request field), both exclusive and inclusive pricing modes; found and resolved a real gap in money-and-tax.md's own two worked examples in the same pass — inclusive pricing combined with a discount on the same line was never jointly specified, resolved as the natural composition of two already-accepted rules. Sprint 29 built M2 item 5, Split Payment — `payments` loosened to one-or-more entries across `cash`/`card`/`other` (FR-028), `PAYMENT_AMOUNT_MISMATCH` restated as a sum check, no schema change needed; confirmed live that Trading Day's own Sprint 26 aggregation query needed zero changes to already exclude a split sale's card/other portions from `expected_cash_minor_units`. Sprint 30 closed M2's last item, Hold/Resume — mobile-only, no server change at all: `sales.status` now transitions `draft`→`held`→`draft`→`completed` on the client, `completeSale` rewritten to transition the existing draft/held row in place; built to navigation-model.md §4's fuller pre-existing requirement (continuous auto-persistence of the active cart from its first item, not merely a hold button), and corrected a real schema-local.md gap along the way — its "Immutable event" classification was never literally true once a draft/held row is genuinely mutated pre-completion. **M2 — Full POS Loop is fully built, all 6 backlog items done.** M3 — Customers, Returns & Refund, conflict-resolution field-merge — was then fully decomposed to item grain, finding that the sync engine has never had a single `.update` operation type for any entity despite several tables being classified "Client-editable" since Phase 13, and that `offline-workflows.md` Finding 1's on-paper `sync_rejections` resolution was never actually built. Sprint 31 built M3's first item, Customers (server) — `customers` table, `sales.customer_id`, `POST`/`GET`/`PATCH`/`DELETE /customers`, `GET /customers/{id}/purchase-history`, live-verified (12/12); found and fixed a real bug live (a Zod `.refine()` returning the wrong error code) and corrected permission-matrix.md's own missing edit/deactivate-customer rows in the same pass. Sprint 32 built M3 item 2, Customers (mobile), as a full-stack item rather than mobile-only — `customer.create` added as the sync engine's third push operation type, `POST /sales` gains an optional server-validated `customer_id`, and the mobile `CustomerPickerSheet` (a bottom sheet over the till, not a route push — FR-050's own wording taken literally) plus full `/customers`/`/customers/:id` browse routes, the attached customer surviving hold/resume (FR-026); live-verified (9/9 server checks, 145/145 `flutter test`). Sprint 33 built M3 item 3, Returns & Refund (server) — `returns`/`return_line_items` tables, `POST`/`GET /returns*`, `POST /returns/{id}/approve`/`reject`, and `return.create`/`return.approve`/`return.reject` as the sync engine's fourth through sixth push operation types; found and corrected two real gaps in schema-server.md's own `returns` table design while writing the spec (a missing `created_by`/`created_at` column pair, and a documented `client_operation_id` column with no working precedent anywhere else in this schema, dropped in favour of `id` alone); resolved DR-014's per-unit-price rounding ambiguity as a dated decision (exact-remaining-amount for a full return, proportional rounding only for a genuine partial); live-verified (22/22). Sprint 34 built M3 item 4, Returns & Refund (mobile) — `/returns/new`/`/returns/:id`/`/returns/approvals`, local `Returns`/`ReturnLineItems` tables, `return.create`/`return.approve`/`return.reject` written to `outbound_queue`; found and fixed a real, blocking gap before writing mobile code (`formatSale` never exposed a sale line item's own `id`, which `POST /returns` needs); resolved the approvals-queue badge placement (no Reports tab exists yet, M4) and WF-013's interrupt/queue split (an inline post-creation prompt, no new realtime infrastructure) as dated decisions rather than left implicit; `flutter analyze`/`flutter test` (176 total mobile tests) clean. Sprint 35 closed M3's last item, conflict-resolution field-merge (`customers` only) — `customer.update` as the sync engine's first `.update` operation type of any kind, `PATCH /customers/{id}` upgraded in place to the same merge-aware service function; found and resolved a real gap while writing the spec (`base_updated_at` alone can't support a field-level 3-way merge, resolved via client-supplied per-field base values, no new server-side history mechanism); mobile gains its first customer-edit screen and a conflict-resolution screen; live-verified 18/18, the exact worked-example scenario (two staff editing the same customer's phone number) provoked for real. **M3 — Customers & Returns is now fully closed, all 5 backlog items done**, satisfying milestones.md's own hard exit criteria for a return completing correctly and a field-edit conflict surfacing in business language. See [implementation-log.md](18-implementation/implementation-log.md) for the full per-sprint record. |

**Legend:** ⚪ Not started · 🟡 Draft · 🔵 In review · 🟢 Approved · 🔴 Blocked

---

## Cross-cutting folders

| Folder | Purpose |
| --- | --- |
| [00-governance](00-governance/) | How we work: documentation standards, Definition of Done, review rules. Applies to every phase. |
| [adr](adr/) | Architecture Decision Records. Every architecturally significant decision, with context, options considered, and consequences. Immutable once accepted. |
| [modules](modules/) | Per-module specifications. One folder per business module, authored during Phase 18 immediately before that module is implemented. |
| [reference](reference/) | External research, vendor limits, competitor analysis, regulatory notes. |
| [assets](assets/) | Diagrams, wireframes, exported images referenced by the documents. |

---

## Non-negotiable rules

1. **Design before code.** No implementation begins before its module specification is approved.
2. **One module at a time.** A module is finished — business rules, schema, API, validation, error
   handling, offline behaviour, realtime behaviour, UI, tests, documentation — before the next
   module starts.
3. **No placeholders.** No `TODO`, no stub, no "implement later" in merged code.
4. **Documentation is updated in the same pull request as the code it describes.**
5. **Every architecturally significant decision gets an ADR.** If someone will ask "why is it like
   this?" in six months, it needs an ADR.

---

## Document index

- [Glossary](GLOSSARY.md) — shared vocabulary. Ambiguous terms cause defects; this file prevents them.
- [Documentation Standards](00-governance/documentation-standards.md)
- [Definition of Done](00-governance/definition-of-done.md)
- [Ways of Working](00-governance/ways-of-working.md)
