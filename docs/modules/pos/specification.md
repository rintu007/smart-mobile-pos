# Module Specification — POS

> **Status:** 🟢 Approved
> **Module:** POS
> **Slice:** V1 — this document scopes only M0's minimal first cut, not the full V1 shape (§1)
> **Version:** 0.10.1
> **Last updated:** 2026-08-16
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 05](../../17-sprints/sprint-05.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

Lets a shop record a completed sale. [backlog.md item 6](../../17-sprints/backlog.md#1-m0--walking-skeleton-fully-decomposed)
scopes M0 to "manual product add to cart..., cash payment only" — no discount, tax, or split
payment (all [M1/M2 scope](../../17-sprints/backlog.md#2-m1m4--module-grain-only-decomposed-when-reached)),
no Trading Day precondition (Trading Day is its own M2-scope module, not yet built), and no
`device_id` (Authentication's device-registration slice — [module registry](../README.md) — isn't
built yet either). This is a real, named gap against the full V1 requirement, the same shape of
scope boundary already documented for Authentication's device revocation and Products' category/unit
fields. §11 states this plainly.

**Also out of scope this sprint:** the mobile till screen UI itself — see §4.

**Closed, Sprint 11:** the stock-ledger effect of a completed sale
([WF-002](../../06-workflows/sales-workflows.md#wf-002--complete-a-single-item-cash-sale) requires
it atomically with the sale) was out of scope when this document was first written — backlog.md
item 7 was its own, later, dependent backlog item. It has since landed: `POST /api/v1/sales` now
writes one `sale` stock movement per line item inside the same transaction as the sale itself — see
[inventory/specification.md](../inventory/specification.md).

**Closed, Sprint 12:** likewise, DR-025's audit-log requirement (backlog.md item 8) was its own
later, dependent item. `POST /api/v1/sales` now also writes one `sale.completed` audit-log entry in
the same transaction — see [audit-log/specification.md](../audit-log/specification.md).

**Closed, Sprint 27 (backlog.md M2 item 3):** per-line Discount, per
[WF-003](../../06-workflows/sales-workflows.md#wf-003--complete-a-sale-with-a-discount) — a
workflow already fully designed in Phase 06, not invented this sprint. A discount below
`shop_settings.discount_auto_approval_threshold_minor_units` ([DR-012](../../03-functional-requirements/business-rules.md))
applies immediately; above it, requires the calling session itself to be Manager/Owner, or a named
Manager/Owner `discount_approved_by` — resolved fresh at request-processing time
([DR-017](../../03-functional-requirements/business-rules.md)), the same integrity guarantee
[Finding 1](../../06-workflows/offline-workflows.md#finding-1--offline-approvals-are-provisional-until-sync-and-that-needs-a-defined-ux)
already established for return approvals, not a stronger live-proof claim. **A real semantic
correction found writing this section:** [money-and-tax.md](../../07-database/money-and-tax.md)'s
already-fixed formula defines `invoice.subtotal_minor_units` as **post-discount, pre-tax** — this
implementation's `subtotal_minor_units` silently meant "pre-discount raw sum" until now, invisible
only because no discount existed yet to make the two values diverge. Corrected in the same PR, not
carried forward as a latent bug for Tax computation (M2 item 4) to trip over.

**Closed, Sprint 28 (backlog.md M2 item 4):** Tax computation, wiring
`shop_settings.tax_mode`/`tax_rate_basis_points`/`pricing_mode`/`rounding_rule` into `POST /sales`
per [money-and-tax.md](../../07-database/money-and-tax.md)'s already-fixed discount-before-tax
formulas. **A real design gap found writing this section, not covered by either of
money-and-tax.md's own worked examples**: §3's worked example is exclusive-pricing-with-discount;
§4's is inclusive-pricing-with-*no* discount — the combination of inclusive pricing *and* a discount
on the same line was never specified. Resolved as a dated correction to money-and-tax.md §4a: for
inclusive pricing, the discount is subtracted from the tax-inclusive gross **before** the
tax-as-residual split runs, the natural composition of "discount reduces taxable value" (§1) with
"tax is the residual of gross minus taxable" (§4) — not a new rule, an explicit statement of what
the two already-accepted rules imply together. `tax_registration_type_at_sale` is snapshotted from
`shop_settings.tax_mode` at sale creation ([DR-009](../../03-functional-requirements/business-rules.md)
via Settings' own already-enforced "rate is 0 outside `standard`" guarantee, not re-validated here).
**Explicitly still deferred**: FR-055/FR-056's actual invoice-document rendering (GSTIN, per-line
HSN/SAC breakup, Bill-of-Supply vs. Tax-Invoice document type/layout) — this sprint computes the
correct numbers; no GSTIN field exists anywhere yet (`shop_settings` has none), and receipt/invoice
document rendering is Receipt & Printing's own scope, not POS's.

**Closed, Sprint 29 (backlog.md M2 item 5):** Split Payment, per
[WF-004](../../06-workflows/sales-workflows.md#wf-004--complete-a-sale-with-split-payment) —
`POST /sales.payments` loosened from exactly one `cash` entry to one-or-more entries across
`cash`/`card`/`other` ([FR-028](../../03-functional-requirements/functional-requirements.md)),
validated by summing every entry against the server-recomputed `grand_total_minor_units`
(`PAYMENT_AMOUNT_MISMATCH`, restated for the multi-entry case — the same code, a stricter check).
No schema change: `sale_payments` was already a to-many relation (M0's own single-row usage was a
scope choice, not a structural limit), and `shop_settings`'s CHECK-free `method` column already
allowed `card`/`other` values that simply had no live writer until now. **WF-004's own diagram
shows exactly two portions** (cash + one other) as the V1 till UI's target shape — this
implementation accepts any number ≥ 1, the natural generalisation of "sum to the total," not a
narrower one; nothing about the till UI needing exactly two changes what the API itself must
validate. Trading Day's `expected_cash_minor_units` computation (Sprint 26) already aggregates
every matching `cash` `sale_payments` row per trading day, not "the sale's one payment" — it needed
no change at all to correctly sum multiple cash portions from the same sale.

**Closed, Sprint 30 (backlog.md M2 item 6 — M2's last item):** Hold/Resume, per
[WF-005](../../06-workflows/sales-workflows.md#wf-005--hold-and-resume-a-sale) and the
[Sale state machine](../../06-workflows/state-machines.md#sale) (both already fully designed in
Phase 06, not invented this sprint) — **mobile-only work**, the first M2 sprint that isn't a
backend change at all: `POST /api/v1/sales` needs no change whatsoever, per this document's own
already-established note that "a held/draft cart is not itself synced to the server as a partial
row" ([sales.md](../../11-api/endpoints/sales.md)).

**A real requirement found while writing this section, broader than the backlog item's own one-line
description:** [navigation-model.md §4](../../09-navigation/navigation-model.md#4-mid-sale-interruption)
already states the active (not-yet-explicitly-held) cart must be "continuously auto-persisted
locally from the moment the first item is added — not only at the moment the Cashier taps 'Hold'...
Durability is unconditional from the first item onward." A literal reading of "Hold/Resume" as "an
explicit Hold button plus a way to get a held cart back" would satisfy WF-005's own four steps but
would silently leave an in-progress (not-yet-held) cart still vulnerable to an app kill —
contradicting a requirement this project's own Phase 09 documentation already fixed. Built to the
fuller, already-documented requirement: every cart mutation (`addProduct`/`decrementProduct`) writes
through to the local `sales`/`sale_line_items` rows immediately, not only an explicit "Hold" tap.

**A second real design gap, found in the same pass**: [schema-local.md](../../07-database/schema-local.md)'s
"Immutable event" classification for `sales`/`sale_line_items`/`sale_payments` — "created locally...
never edited after creation" — cannot be literally true once a cart is auto-persisted while still
`draft`/`held`; the row is genuinely mutated (line items replaced, totals recomputed) on every cart
change, right up until it becomes `completed`. Resolved as a dated correction to schema-local.md:
these three tables are immutable **only from the moment `status` first becomes `'completed'`**,
mirroring `schema-server.md`'s own trigger ("no `UPDATE`/`DELETE` once `status = 'completed'`")
exactly — this was already the server's own rule; the local classification simply hadn't been
checked against it since it predates any code that could expose the gap (no draft/held row was ever
written locally before this sprint).

**A third resolved design decision**: the provisional invoice number ([ADR-0008](../../adr/ADR-0008-offline-invoice-numbering.md))
is assigned **once, at the moment a cart's first item is added** (i.e. at `Draft` creation) and
never reassigned — not deferred to the moment of payment. This means a cart that's started and then
abandoned or explicitly cancelled "burns" a provisional number, leaving a gap in the local
provisional sequence. Accepted deliberately: ADR-0008's own gapless guarantee applies to the
**canonical** (server-assigned) sequence only, never claimed for the provisional one; real-world
receipt-numbering schemes routinely have gaps from voided/abandoned transactions, and the
alternative (deferring assignment to payment time) would mean a cart's own visible reference number
changes identity partway through its life, which ADR-0008's "shown on the receipt immediately... and
is permanent" framing is clearly written to rule out. The practical effect: `completeSale` now
**updates the existing draft/held row in place** (same `id`, same provisional number) rather than
inserting a fresh row at the moment of payment — the single most consequential implementation change
this sprint makes to the existing M0 write path.

**Explicitly still deferred**: WF-006 (cancel/discard an in-progress or held cart) — a distinct,
separately-numbered Phase 06 workflow with its own FR, not part of backlog item 6's "Hold/Resume"
wording. A held cart can accumulate in the Held Carts list with no way to remove it until this
lands; named as a real, continuing gap, not silently absorbed into this sprint's scope. Also
deferred: `stock_movements`/audit-log writes from the mobile write path (a pre-existing gap found
while reading `DriftSaleRepository`, unrelated to hold/resume — the local repository has never
written either, matching the server path's own behaviour only for `stock_movements`, since the
mobile side has no local audit-log table at all yet).

## 2. Business rules

- A sale belongs to exactly one tenant and store; the server, never the client, computes
  `subtotal_minor_units`/`grand_total_minor_units` from each line item's **current**
  `products.price_minor_units` — [api-principles.md §7](../../11-api/api-principles.md#7-the-server-recomputes-it-never-trusts-a-client-figure).
- A line item's `client_unit_price_minor_units` is compared against the server's own lookup; a
  mismatch is rejected with `PRICE_MISMATCH` (409) — M0 has no offline queue path yet (no mobile
  write path exists — §4), so every sale in this sprint's scope is the "connected device" case from
  [sales.md](../../11-api/endpoints/sales.md); the offline-queued exception documented there doesn't
  apply to anything this sprint actually builds.
- Exactly one `cash` payment is required, and its `amount_minor_units` must equal the computed
  `grand_total_minor_units` exactly — split payment and change-due tracking are both M1/M2 scope.
- At least one line item is required; a `quantity` of zero or a negative value is rejected —
  fractional quantities are rejected too (Units doesn't exist yet, so nothing establishes whether a
  product allows them — [FR-037](../../03-functional-requirements/functional-requirements.md)'s
  precondition doesn't exist yet), a whole-number-only simplification, named here.
- Creation is idempotent on the client-generated `id` — replaying the same request with the same
  `id` returns the original sale unchanged, without re-running price validation (a price that moved
  *after* a legitimate first success must not turn a replay into a spurious `PRICE_MISMATCH`).
- **Permission-checked as of Sprint 23**: `POST /sales` requires any role (Cashier, Manager, and
  Owner may all "complete a sale" per [permission-matrix.md](../../05-personas/permission-matrix.md)),
  per [roles-permissions/specification.md](../roles-permissions/specification.md).
- [DR-011](../../03-functional-requirements/business-rules.md): a line's discount is expressed as
  **either** `discount_percent_basis_points` **or** `discount_amount_minor_units`, never both —
  rejected with `VALIDATION_FAILED` if both are present on the same line.
- Server-computed, never client-trusted: `line_discount_minor_units` — `ROUND(line_subtotal ×
  percent / 10000, rounding_rule)` for a percent discount, the flat amount directly for a fixed
  one (capped at the line's own pre-discount subtotal; a discount exceeding 100% of a line is
  rejected with `VALIDATION_FAILED`, not silently clamped).
  `sales.discount_total_minor_units = Σ line_discount_minor_units`.
- [DR-012](../../03-functional-requirements/business-rules.md): `discount_total_minor_units >
  shop_settings.discount_auto_approval_threshold_minor_units` requires authority beyond an ordinary
  Cashier — satisfied either by the calling session itself already being Manager/Owner ([DR-020](../../03-functional-requirements/business-rules.md)),
  or by an optional `discount_approved_by` field naming a **different** user who resolves, at
  request-processing time, to an active Manager/Owner role at this store. Neither condition met →
  `DISCOUNT_REQUIRES_APPROVAL` (409), the sale is not created at all — matching
  [WF-003](../../06-workflows/sales-workflows.md#wf-003--complete-a-sale-with-a-discount)'s own
  "rejected, sale continues undiscounted" framing (in this synchronous, single-request design, that
  means the whole `POST /sales` call fails, not a partial/undiscounted fallback — the client is
  expected to remove the discount and retry if it can't clear approval).
- **Correction, Sprint 27**: `sales.subtotal_minor_units` now means what
  [money-and-tax.md](../../07-database/money-and-tax.md) always specified —
  **post-discount, pre-tax** (`Σ line_taxable_value`) — not the pre-discount raw sum this
  implementation silently computed before any discount existed to expose the difference.
  [DR-008](../../03-functional-requirements/business-rules.md): tax is server-computed per line
  from `shop_settings`' own already-validated fields (never client-supplied), per
  [money-and-tax.md §1](../../07-database/money-and-tax.md#1-the-rule-restated-precisely):
  **exclusive pricing** — `line_tax_minor_units = ROUND(line_taxable_value × tax_rate_basis_points
  / 10000, rounding_rule)`, `line_total_minor_units = line_taxable_value + line_tax_minor_units`.
  **Inclusive pricing** (per §4's residual method, extended to the discount case by this sprint's
  own dated correction, §1 above) — the pre-discount `unit_price × quantity` is already
  tax-inclusive; the discount is subtracted from that gross first, then
  `line_taxable_value = ROUND(gross_after_discount × 10000 / (10000 + tax_rate_basis_points),
  rounding_rule)`, `line_tax_minor_units = gross_after_discount − line_taxable_value` (residual, per
  §4's own stated reasoning for why re-multiplying the rounded taxable value doesn't sum back
  exactly), `line_total_minor_units = gross_after_discount`. `sales.tax_total_minor_units = Σ
  line_tax_minor_units` (never independently rounded — DR-008's own explicit rule).
  `grand_total_minor_units = subtotal_minor_units + tax_total_minor_units`.
- `sales.tax_registration_type_at_sale` snapshots `shop_settings.tax_mode` at creation time — a
  point-in-time copy, per schema-server.md's own stated reasoning ("a shop's tax status can change
  after old sales exist"), not a live join. Since `PATCH /settings` already forces
  `tax_rate_basis_points` to `0` outside `tax_mode: 'standard'` ([DR-009](../../03-functional-requirements/business-rules.md),
  settings/specification.md §2), this module trusts that invariant rather than re-checking it.
- [FR-028](../../03-functional-requirements/functional-requirements.md): `POST /sales.payments`
  accepts one or more entries, each `{ method: 'cash'|'card'|'other', amount_minor_units }` — the
  sum across every entry must equal the server-recomputed `grand_total_minor_units` exactly
  (`PAYMENT_AMOUNT_MISMATCH` otherwise, the same code M0 already reserved, now checking a sum
  instead of a single value). No live payment-network authorisation exists in V1 — `card`/`other`
  are manually recorded amounts, per [WF-004](../../06-workflows/sales-workflows.md#wf-004--complete-a-sale-with-split-payment)'s
  own explicit "not a processed transaction" framing.
- **Mobile-only, Sprint 30** — the [Sale state machine](../../06-workflows/state-machines.md#sale):
  `Draft → Held` (hold), `Held → Draft` (resume), `Draft → Completed` (payment confirmed),
  `Draft → Cancelled`/`Held → Cancelled` (cancel — **not built this sprint**, §1). **Held cannot go
  directly to Completed** — a held cart is always resumed back to `Draft` first, never paid directly
  from the held list; the resume action itself performs this transition, there is no separate "pay
  from list" shortcut.
- The active cart's local `sales`/`sale_line_items` rows are kept continuously in sync with
  `CartController`'s in-memory state on every mutation — [FR-026](../../03-functional-requirements/functional-requirements.md).
  If the last line item is removed (decremented to zero), the draft row is deleted entirely, not
  left behind as an empty row — an empty cart has nothing to hold.
- Resuming a different held cart while the active cart already has items **implicitly holds the
  active cart first** — nothing is silently discarded; the previously-active cart becomes another
  entry in the held list rather than being lost. Not specified explicitly by WF-005 (which only
  describes a single cart's own lifecycle), resolved here as the only option that satisfies FR-026's
  durability guarantee for *both* carts simultaneously.
- [FR-026](../../03-functional-requirements/functional-requirements.md): a held cart survives an
  app kill/restart intact — trivially true once the active-cart auto-persistence above holds, since
  a held cart is simply a `status = 'held'` row like any other, read back from the same local table
  on next launch, not a separate in-memory-only mechanism that could be lost.

## 3. Database tables and relationships

`sales`, `sale_line_items`, `sale_payments`, per
[schema-server.md](../../07-database/schema-server.md) Context 5 — but, like Products (Sprint 04),
this sprint implements only a subset of each table's full column list.

`sales`: `id`, `tenant_id`, `store_id`, `trading_day_id` (optional, Sprint 26),
`canonical_invoice_number`/`financial_year` (Sprint 24), `status` (always `'completed'` this
sprint), `provisional_invoice_number`, `subtotal_minor_units`, `discount_total_minor_units`
(Sprint 27), `tax_total_minor_units`/`tax_registration_type_at_sale` (new, Sprint 28),
`grand_total_minor_units`, `completed_at`, `created_at`, `created_by`. **Not yet built:**
`device_id`, `customer_id` — added once device-registration/Customers exist.

`sale_line_items`: `id`, `sale_id`, `product_id`, `quantity`, `unit_price_minor_units`,
`line_discount_minor_units` (Sprint 27), `line_tax_minor_units`/`tax_rate_basis_points` (new,
Sprint 28, both `DEFAULT 0`), `line_total_minor_units`. **Not yet built:** `variant_id` (V2+ stub),
`hsn_sac_code_at_sale` (informational only per RR-003, not needed for the tax computation itself —
deferred alongside FR-055/056's document-rendering scope, §1).

`sale_payments`: `id`, `sale_id`, `method` (`'cash'`/`'card'`/`'other'` all live as of Sprint 29 —
[schema-server.md](../../07-database/schema-server.md)'s full enum was already accepted by the Zod
schema since M0 for forward-compatibility, per [Products' precedent](../products/specification.md#3-database-tables-and-relationships);
this sprint is simply the first with a caller that can actually send `card`/`other`), `amount_minor_units`.
**No schema change this sprint** — `sale_payments` was already a to-many relation (§1's own note);
Split Payment is a Zod-validation and business-rule change only.

`provisional_invoice_number` was accepted as a plain client-supplied non-empty string in Sprint 05
— the server never generates or validates it against
[ADR-0008](../../adr/ADR-0008-offline-invoice-numbering.md)'s scheme, only stores it. **Sprint 09**
built the scheme's local half (`apps/mobile/lib/core/invoicing/invoice_number_generator.dart`,
`device_identity`/`local_provisional_sequence` local tables — see
[schema-local.md](../../07-database/schema-local.md)) as part of the till screen's local write
path, deliberately narrower than the full ADR: the device short id has no corresponding `devices`
server row (Authentication's device-registration slice isn't built), and canonical-number
assignment (the server half) has no caller yet either, since the sync engine (backlog.md item 9)
doesn't exist. Every sale this module produces still has `canonical_invoice_number = null`.

RLS: tenant-scoped, same template as `stores`/`products`
([supabase/sql/003_rls_stores.sql](../../../supabase/sql/003_rls_stores.sql)) for `sales`.
`sale_line_items`/`sale_payments` have no independent `tenant_id`/RLS, matching
[schema-server.md](../../07-database/schema-server.md)'s own stated design — access is via
`sale_id`, never queried directly across tenants.

### Local (Drift) schema — Sprint 30

`apps/mobile/lib/core/database/tables/sales.dart` gains one column: `created_at` (nullable
`DateTime`, schema v3→v4, `m.addColumn`) — the local `Sales` table never had one at all before this
sprint (a real, pre-existing gap: every server Tier 1/2 table has `created_at` by convention, per
schema-server.md's own header note; the local M0-minimal slice simply omitted it since nothing
locally needed to distinguish "when was this row first written" from "when did it complete" until
now). Existing `'completed'` rows are backfilled (`created_at = completed_at`) in the same migration
step — a reasonable historical approximation, not a claim of precision, matching this codebase's
own "a real founder device already has real local data" migration discipline. Used to order the
Held Carts list, most-recently-held first (matching `listCompletedSales`' own existing
most-recent-first convention).

**No other local schema change.** `provisional_invoice_number` stays `NOT NULL` (§1's third design
decision — assigned once, at `Draft` creation, never deferred); `status` already accepted
`'draft'`/`'held'`/`'cancelled'` values in the column's own documented intent, simply never written
by any code path before this sprint.

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/sales` | **Implemented Sprint 05, extended since.** Request now also accepts an optional `trading_day_id` (Sprint 26), and per-line `discount_percent_basis_points`/`discount_amount_minor_units` plus a top-level `discount_approved_by` (Sprint 27). **Tax (Sprint 28) needs no new request field at all** — `tax_rate_basis_points`/`tax_mode`/`pricing_mode` are read straight from `shop_settings`, never client-supplied, per DR-008. **`payments` (Sprint 29) loosened from exactly one `cash` entry to one-or-more across `cash`/`card`/`other`**, summed against `grand_total_minor_units`. **`customer_id` (Sprint 32) accepted as an optional field** — [customers/specification.md §1a](../customers/specification.md#1a-sprint-32--customers-mobile-m3-item-2), validated against the caller's tenant when supplied (`NOT_FOUND` otherwise, the same `category_id`/`unit_id` existence-check shape products/service.ts already established). Still not the full shape [sales.md](../../11-api/endpoints/sales.md) documents — device fields remain unbuilt. Requires any role (`requirePermission`, Sprint 23). |
| `GET /sales/{id}`, `GET /sales`, `GET /sales/lookup` | **Built Sprint 24** (M1 item 8, `sales-invoices` module) — this row was stale (still said "not yet implemented") until corrected here; see [sales-invoices/specification.md](../sales-invoices/specification.md). |
| **Hold/Resume (Sprint 30)** | **No server endpoint at all, by design** — §1's own already-established note. A held/draft cart never crosses the wire; only the eventual `POST /sales` completion call does, exactly as today. |

**Mobile till screen (`apps/mobile/lib/features/pos/`) — built Sprint 09.** Sprint 05 deferred it
("prove the server contract live, defer the mobile UI," a now-three-sprints-running pattern its own
risk register flagged); Sprint 09 closed that gap once items 5 (local products) and 13 (store
context) unblocked it. The till screen writes locally (`sales`/`sale_line_items`/`sale_payments` +
one `outbound_queue` row, atomically) and never calls `POST /api/v1/sales` directly — per
sync-architecture.md's "the local write path is the one and only way any entity is created or
changed on-device," the same discipline Sprint 07's product-creation write already established.
Nothing drains `outbound_queue` yet (the sync engine, backlog.md item 9, is still unbuilt), so this
module's server endpoint and its mobile write path are proven independently, not yet end-to-end.

## 5. Validation rules (client and server)

Request body for `POST /api/v1/sales` (Zod schema, server-side):

| Field | Rule |
| --- | --- |
| `id` | UUIDv4, required |
| `store_id` | UUIDv4, required |
| `provisional_invoice_number` | Non-empty string, required, max 100 chars |
| `line_items` | Array, min length 1, required |
| `line_items[].product_id` | UUIDv4, required |
| `line_items[].quantity` | Positive integer, required (no fractional quantities — §2) |
| `line_items[].client_unit_price_minor_units` | Non-negative integer, required |
| `payments` | Array, **min length 1** (loosened from exactly 1, Sprint 29), required |
| `payments[].method` | `.enum(["cash", "card", "other"])` (loosened from a `"cash"` literal, Sprint 29), required |
| `payments[].amount_minor_units` | Non-negative integer, required |
| `trading_day_id` (Sprint 26) | UUIDv4, optional |
| `line_items[].discount_percent_basis_points` (Sprint 27) | `.int().min(0).max(10000)`, optional, mutually exclusive with the field below |
| `line_items[].discount_amount_minor_units` (Sprint 27) | `.int().nonnegative()`, optional, mutually exclusive with the field above — Zod `.refine` rejects a line carrying both |
| `discount_approved_by` (Sprint 27) | UUIDv4, optional |
| `customer_id` (Sprint 32) | UUIDv4, optional |

Server-side, beyond schema validation: every `product_id` must resolve to a real, non-deactivated
product in the caller's tenant (`NOT_FOUND` otherwise); a supplied `customer_id` must resolve to a
real `customers` row in the caller's tenant (`NOT_FOUND` otherwise — deactivated customers are
still valid targets, per customers/specification.md §2's soft-delete stance); each line's
`client_unit_price_minor_units` must equal the product's current `price_minor_units`
(`PRICE_MISMATCH` otherwise); a flat `discount_amount_minor_units` may not exceed its own line's
pre-discount subtotal (`VALIDATION_FAILED` otherwise); if the resulting
`discount_total_minor_units` exceeds `shop_settings.discount_auto_approval_threshold_minor_units`,
either the caller's own resolved role or `discount_approved_by`'s resolved role must be
Manager/Owner (`DISCOUNT_REQUIRES_APPROVAL` otherwise); **the sum of every `payments[].amount_minor_units`**
(Sprint 29 — was a single value's own equality check before Split Payment) must equal the computed
`grand_total_minor_units` exactly (`PAYMENT_AMOUNT_MISMATCH` otherwise).

## 6. Error handling and user-facing messages

`VALIDATION_FAILED` (422) for schema failures, `NOT_FOUND` (404) for an unknown `product_id` — both
already cross-cutting codes in [error-catalogue.md](../../11-api/error-catalogue.md), reused as-is
rather than inventing module-specific equivalents. `PRICE_MISMATCH` (409, already catalogued) for a
stale cached price. `PAYMENT_AMOUNT_MISMATCH` (409) was added Sprint 05.
**`DISCOUNT_REQUIRES_APPROVAL` (409) is new this sprint (Sprint 27)** — the resulting discount
exceeds the shop's threshold and neither the caller nor a named `discount_approved_by` resolves to
an active Manager/Owner at this store — added to [error-catalogue.md](../../11-api/error-catalogue.md).
None of these codes are reachable from the
till screen yet (Sprint 09): the mobile write path never calls the server directly (§4), so a stale
local price or a payment-amount mismatch can't surface here until the sync engine (item 9) exists to
run the request and relay a rejection back. The till screen's own error text (§10's widget tests)
covers only a failed *local* write, a distinct failure mode from any of the codes above.

## 7. Offline behaviour

The server endpoint (`POST /api/v1/sales`) requires connectivity, same as any `POST` — that half was
proven live, connected, in Sprint 05. Per [sales.md](../../11-api/endpoints/sales.md), `POST /sales`
is documented as **offline-capable** in the full V1 design; **Sprint 09 built that offline path on
the mobile side** — the till screen completes a sale entirely locally (no network call), enqueuing a
`sale.create` operation shaped identically to this endpoint's own request body
([sync-api.md §1](../../11-api/sync-api.md#1-one-request-shape)). What's still missing is the piece
that actually connects the two: the sync engine (backlog.md item 9) that would drain
`outbound_queue` and call this endpoint. Until then, `PRICE_MISMATCH`'s offline-queued exception
(§2) is built for (the till screen genuinely operates offline) but never actually exercised end to
end — nothing has synced yet for a price to have moved out from under.

## 8. Realtime behaviour

None specified for V1 in this sprint's scope — no requirement found for live sale-list push to
other devices.

## 9. UI specification

`apps/mobile/lib/features/pos/` per
[mobile-structure.md](../../08-folder-structure/mobile-structure.md) — **built Sprint 09.**
`/pos` per [route-map.md](../../09-navigation/route-map.md): a product list (from the local
`products` cache, tap to add), a running cart with per-line quantity and a decrement action, a
grand total, and a "Complete sale (cash)" action. No "amount tendered" field — §2 requires the cash
payment to equal the grand total exactly, so the cart total *is* the amount charged. Reached from
`HomeScreen` via a button, the same pattern `/catalogue/add`'s FAB established in Sprint 07 — not a
claim that `/pos` is the shell's home route yet; the bottom-nav shell in
[navigation-model.md](../../09-navigation/navigation-model.md) isn't built. Barcode scan (no
scanning yet — backlog.md item 6), hold/resume, and a bottom-nav shell are all out of scope.

**Sprint 30 additions:**

- `TillScreen` gains a `pos_hold_button` next to `pos_complete_sale_button` — enabled only when the
  cart has at least one line (WF-005 step 1, ≤1 tap per
  [tap-count-audit.md](../../09-navigation/tap-count-audit.md)). Holding clears the active on-screen
  cart (the row itself stays in local storage as `status = 'held'`).
- `TillScreen`'s app bar gains a `pos_held_carts_button` icon, per
  [navigation-model.md §2](../../09-navigation/navigation-model.md#2-the-persistent-elements)'s
  already-specified "Hold" icon — always navigates to `/pos/hold` (new route,
  [route-map.md](../../09-navigation/route-map.md) already reserved it).
- `/pos/hold` (`HeldCartsScreen`, new): on build, resolves the held-cart list.
  **Zero held** → an empty-state message. **Exactly one held** → auto-resumes it and pops
  immediately, no list frame shown — the tap-count-audit's own documented 1-tap budget for this
  case. **Two or more held** → shows the list (invoice number, item count, total, "held" relative
  time from the new `created_at` column); tapping an entry resumes it and pops —
  tap-count-audit.md's own **documented, accepted exception**: 2 taps in the multi-held case,
  1 over budget, because "resuming the wrong cart in under a tap would be a worse outcome than one
  extra tap to pick the right one."
- Resuming an entry loads its line items back into the active cart and pops back to `/pos` — per
  §2's own resolved design decision, implicitly holding whatever cart was already active first if
  it had items.

## 10. Test plan

**Sprint 05 scope:**
- Unit test: `POST /api/v1/sales` creates one `sales` row plus its `sale_line_items` and
  `sale_payments` rows, with server-computed totals matching the sum of current product prices.
- Unit test: a mismatched `client_unit_price_minor_units` is rejected with `PRICE_MISMATCH`, and no
  rows are written.
- Unit test: a payment amount not equal to the computed grand total is rejected with
  `PAYMENT_AMOUNT_MISMATCH`.
- Unit test: a retry with the identical `id` returns the original sale unchanged (idempotent
  replay), without re-running price validation.
- Unit test: an unknown `product_id` is rejected with `PRODUCT_NOT_FOUND`.
- Cross-tenant negative test: a different tenant's session cannot read this sale's row directly —
  requires RLS (§3), run live.
- **Real HTTP request required before this endpoint is marked done** — Sprint 02's addendum rule.

**Sprint 09 scope:**
- Unit test: `InvoiceNumberGenerator` produces `{device_short_id}-{financial_year}-{sequence}`; the
  device short id is generated once and stays stable; the sequence increments within one financial
  year; the financial year rolls over on April 1, restarting the sequence at 1.
- Unit test: `DriftSaleRepository.completeSale` writes one `sales` row, its line items, its cash
  payment, and one `outbound_queue` row, all atomically, with a payload shaped identically to
  `POST /api/v1/sales`'s own request body.
- Unit test: a retry with the identical `id` returns the original sale unchanged (idempotent
  replay) without writing a second row set or advancing the invoice sequence.
- Unit test: the write is atomic — an injected failure (a pre-seeded conflicting `outbound_queue`
  row) leaves zero `sales`/`sale_line_items`/`sale_payments`/`local_provisional_sequence` rows
  behind, extending Sprint 07's single-row atomicity proof to a multi-row write.
- Unit tests: `CartController` — adding an already-present product increments its line rather than
  duplicating one; decrementing to zero removes the line; the grand-total provider matches the sum
  of line totals.
- Widget tests (`TillScreen`, overridden providers, no device/network): tapping a product adds it to
  the cart and updates the visible total; the "Complete sale" button is disabled on an empty cart;
  completing a sale shows the resulting provisional invoice number and clears the cart; a failed
  local write renders inline error text and preserves the cart.

**Sprint 27 scope (Discount):**
- Unit tests (`pos/service.test.ts`): a percent discount and a flat discount both compute
  `line_discount_minor_units` correctly and roll up into `discount_total_minor_units`; a line
  carrying both discount fields is rejected with `VALIDATION_FAILED`; a flat discount exceeding its
  own line's subtotal is rejected with `VALIDATION_FAILED`; a discount at/under threshold applies
  with no approver needed; a discount over threshold from a Cashier with no `discount_approved_by`
  is rejected with `DISCOUNT_REQUIRES_APPROVAL`; the same over-threshold discount succeeds when the
  caller's own session is Manager/Owner, and separately when a valid `discount_approved_by` is
  supplied; an invalid/wrong-tenant/insufficient-role `discount_approved_by` is rejected the same
  way as a missing one; `subtotal_minor_units` reflects the corrected post-discount formula (§1's
  named correction).
- **Live verification, real database, throwaway tenant (deleted after)** — see
  [sprint-27.md](../../17-sprints/sprint-27.md) for the exact checks and results.

**Sprint 28 scope (Tax computation):**
- Unit tests (`pos/service.test.ts`): exclusive pricing computes `line_tax_minor_units` correctly
  from `tax_rate_basis_points` and rolls up into `tax_total_minor_units`; inclusive pricing computes
  the same via the residual method; a discount combined with inclusive pricing subtracts from the
  gross before the residual split runs (§1/§2's dated correction); `tax_mode: 'unregistered'`/
  `'composition'` produces zero tax (trusting Settings' own already-enforced invariant, not
  re-validated here); `tax_registration_type_at_sale` snapshots the shop's `tax_mode` at creation;
  `grand_total_minor_units = subtotal_minor_units + tax_total_minor_units` holds exactly across a
  multi-line, mixed-discount sale (the same summation-consistency property money-and-tax.md §3's
  own worked example verifies by hand).
- **Live verification, real database, throwaway tenant (deleted after)** — see
  [sprint-28.md](../../17-sprints/sprint-28.md) for the exact checks and results.

**Sprint 29 scope (Split Payment):**
- Unit tests (`pos/service.test.ts`): two `payments` entries (`cash` + `card`) summing exactly to
  `grand_total_minor_units` succeed, each recorded individually; a three-entry split (`cash` +
  `card` + `other`) also succeeds; entries summing to anything other than the grand total are
  rejected with `PAYMENT_AMOUNT_MISMATCH`; a single `card`-only payment (no cash at all) succeeds,
  confirming the loosened schema doesn't silently assume cash is always present.
- An empty `payments` array is rejected with `VALIDATION_FAILED` at the Zod layer (schema's own
  `min(1)`, enforced in the Route Handler before `createSale` is ever called) — a live-verification
  check, not a `pos/service.test.ts` unit test, matching how `line_items`' own `min(1)` is verified.
- **Live verification, real database, throwaway tenant (deleted after)** — see
  [sprint-29.md](../../17-sprints/sprint-29.md) for the exact checks and results, including that a
  split sale's cash portion (not its card/other portions) is exactly what Trading Day's
  `expected_cash_minor_units` sums, unchanged from Sprint 26's own aggregation query.

**Explicitly deferred:** hold/resume (M2 item 6), any mobile UI for applying a discount, viewing a
tax breakdown, entering a Manager-approval override, or choosing split payment, FR-055/056's
invoice-document rendering (§1).

**Sprint 30 scope (Hold/Resume, mobile-only):**
- Repository tests (`drift_sale_repository_test.dart`, real in-memory Drift DB): adding the first
  cart line creates a `status = 'draft'` row with a real provisional invoice number; subsequent
  mutations update the same row's line items/totals in place, never inserting a second row;
  removing the last line deletes the draft row entirely; `holdSale` transitions `draft → held`;
  `resumeSale` transitions `held → draft` and returns the correct line items; `listHeldSales`
  returns only `held` rows, most-recently-held first; `completeSale` on an existing draft/held row
  updates it in place (same `id`, same provisional number) rather than inserting a new row;
  `completeSale` replayed on an already-`completed` `id` is idempotent (unchanged from M0).
- Provider tests (`pos_providers_test.dart`, `ProviderContainer`): `CartController` persists a draft
  on every mutation; `hold()` clears the active state and leaves the row `held`; resuming a held
  cart while a different cart is already active implicitly holds the active one first (§2's own
  resolved decision), verified by asserting both rows' end states.
- Widget tests (`till_screen_test.dart`, `held_carts_screen_test.dart`, using this codebase's
  existing hand-rolled Fake-repository convention): the Hold button is disabled on an empty cart;
  tapping it clears the visible cart; the Held Carts screen auto-resumes and pops with exactly one
  held cart; shows a picker list with two or more; tapping a list entry resumes and pops.
- **No live-verification step** — this sprint has no server-side change at all (§1), so there is no
  analog to the backend sprints' real-HTTP-request proof; `flutter analyze`/`flutter test` passing
  against the real (in-memory) Drift engine is this sprint's equivalent rigor, per this project's
  own established mobile-sprint precedent (Sprint 09/20/21).

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [FR-024](../../03-functional-requirements/functional-requirements.md) (single-item cash sale in ≤3 actions) | §9 | **Partially met** — the till screen exists and a single-item cash sale is tap-product, tap-complete (2 taps); no formal tap-count audit against patterns.md has been run, matching how [route-map.md](../../09-navigation/route-map.md)'s own audit process works for other screens |
| [FR-042](../../03-functional-requirements/functional-requirements.md) (completing a sale records a negative stock-ledger entry) | — | **Not met** — stock ledger is backlog.md item 7, a later sprint (§1) |
| [WF-002](../../06-workflows/sales-workflows.md#wf-002--complete-a-single-item-cash-sale) (single-item cash sale workflow) | §2, §5, §9 | **Partially met** — the server recompute/payment-validation half (Sprint 05) and the mobile local-write half (Sprint 09) are both built; the two are not yet connected (no sync engine), and the atomic sale+stock-movement transaction (§1) is not built |
| [api-principles.md §7](../../11-api/api-principles.md#7-the-server-recomputes-it-never-trusts-a-client-figure) (server recomputes, never trusts a client figure) | §2, §5 | Met |
| [ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md) (client-generated UUID PKs, idempotent creation) | §2 | Met |
| [DR-011](../../03-functional-requirements/business-rules.md) (discount: percent or fixed, never both) | §2, §5 | Met |
| [DR-012](../../03-functional-requirements/business-rules.md) (over-threshold discount needs Manager+ approval) | §2, §6, §10 | Met |
| [WF-003](../../06-workflows/sales-workflows.md#wf-003--complete-a-sale-with-a-discount) (discount workflow) | §1, §2 | Met for the backend contract; no mobile UI yet (§9 unchanged this sprint) |
| [DR-008](../../03-functional-requirements/business-rules.md) (tax formula, discount-before-tax) | §1, §2 | Met, both pricing modes |
| [DR-009](../../03-functional-requirements/business-rules.md) (composition/unregistered → zero tax) | §2 | Met — trusts Settings' own already-enforced invariant |
| [money-and-tax.md](../../07-database/money-and-tax.md) (rounding, inclusive residual method) | §1, §2 | Met, incl. this sprint's own dated extension to the discount+inclusive combination |
| [FR-055](../../03-functional-requirements/functional-requirements.md)/[FR-056](../../03-functional-requirements/functional-requirements.md) (GST invoice document rendering) | — | **Not met** — this module computes the numbers; document rendering is Receipt & Printing's own scope, named deferred (§1) |
| [FR-028](../../03-functional-requirements/functional-requirements.md) (split payment across two or more methods) | §2, §4, §5 | Met for the backend contract; no mobile UI yet |
| [WF-004](../../06-workflows/sales-workflows.md#wf-004--complete-a-sale-with-split-payment) (split payment workflow) | §1, §2 | Met — API generalises WF-004's two-portion UI target to N ≥ 1 entries, per §1's own reasoning |
| [FR-026](../../03-functional-requirements/functional-requirements.md) (a held cart survives an app kill/restart) | §2, §3 | Met |
| [FR-027](../../03-functional-requirements/functional-requirements.md) (holding a cart records no stock movement) | §2 | Met — a draft/held row is never a `stock_movements` trigger, only `completeSale` is (and only once fully hooked up — §1's own named pre-existing gap) |
| [WF-005](../../06-workflows/sales-workflows.md#wf-005--hold-and-resume-a-sale) (hold/resume workflow) | §1, §2, §9 | Met |
| [Sale state machine](../../06-workflows/state-machines.md#sale) | §2 | Met for `Draft`/`Held`/`Completed`; `Cancelled` reachable in the schema but no UI reaches it yet (WF-006, named deferred, §1) |
| [navigation-model.md §4](../../09-navigation/navigation-model.md#4-mid-sale-interruption) (continuous auto-persistence from the first item) | §1, §2 | Met |
| [tap-count-audit.md](../../09-navigation/tap-count-audit.md) (hold/resume tap budgets) | §9 | Met, including the documented, accepted 2-tap exception for 2+ held carts |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-01 | First version — written to drive Sprint 05's implementation of `POST /api/v1/sales`. Scope deliberately narrow (cash-only, no trading day/device/tax/discount); the stock-ledger effect and the mobile till screen both named as not-yet-met rather than silently claimed. |
| 0.2.0 | 2026-08-02 | Sprint 09: mobile till screen (`/pos`) and its local write path built — cart, cash-only completion, `sales`/`sale_line_items`/`sale_payments` + `outbound_queue` written atomically, ADR-0008's local invoice-numbering half implemented as a deliberately narrower slice (no `devices` row, no canonical-number assignment). The server endpoint and the mobile write path are proven independently; nothing yet drains `outbound_queue` to connect them (backlog.md item 9). |
| 0.3.0 | 2026-08-13 | Sprint 11: closed this document's own named stock-ledger gap — `POST /api/v1/sales` now writes one `sale` stock movement per line item inside the same transaction as the sale, per [inventory/specification.md](../inventory/specification.md). |
| 0.4.0 | 2026-08-13 | Sprint 12: closed the audit-log gap (DR-025, backlog.md item 8) — `POST /api/v1/sales` now also writes one `sale.completed` audit-log entry in the same transaction, per [audit-log/specification.md](../audit-log/specification.md). |
| 0.5.0 | 2026-08-14 | Sprint 23: permission enforcement applied — `POST /sales` now requires any active role (Cashier, Manager, or Owner). |
| 0.6.0 | 2026-08-14 | Sprint 27 (backlog.md M2 item 3): per-line Discount built, per WF-003 (already fully designed in Phase 06). `discount_percent_basis_points`/`discount_amount_minor_units` (mutually exclusive, DR-011), server-computed `line_discount_minor_units`/`discount_total_minor_units`, `DISCOUNT_REQUIRES_APPROVAL` (DR-012) satisfied by the caller's own Manager/Owner role or an optional `discount_approved_by`. Corrected `subtotal_minor_units` to the post-discount, pre-tax meaning money-and-tax.md always specified — invisible until discount existed to make it diverge from the pre-discount sum. |
| 0.7.0 | 2026-08-14 | Sprint 28 (backlog.md M2 item 4): Tax computation built — `tax_total_minor_units`/`line_tax_minor_units`/`tax_rate_basis_points`/`tax_registration_type_at_sale`, wired entirely from `shop_settings` (DR-008), both exclusive and inclusive pricing modes. Found and resolved a real gap money-and-tax.md's own two worked examples never jointly covered: inclusive pricing combined with a discount on the same line — resolved as a dated correction (discount subtracted from the tax-inclusive gross before the residual tax split runs), the natural composition of two already-accepted rules, not a new one. FR-055/056's invoice-document rendering remains explicitly deferred to Receipt & Printing. |
| 0.8.0 | 2026-08-14 | Sprint 29 (backlog.md M2 item 5): Split Payment built, per WF-004. `payments` loosened from exactly one `cash` entry to one-or-more across `cash`/`card`/`other` (FR-028), summed against `grand_total_minor_units` (`PAYMENT_AMOUNT_MISMATCH` restated for the multi-entry case). No schema change — `sale_payments` was already a to-many relation; Trading Day's `expected_cash_minor_units` aggregation (Sprint 26) needed no change either, since it already sums every matching cash row regardless of how many belong to one sale. |
| 0.9.0 | 2026-08-14 | Sprint 30 (backlog.md M2 item 6, **M2's last item**): Hold/Resume built — mobile-only, no server change at all. Per WF-005/the Sale state machine (both already fully designed in Phase 06). Built to a fuller requirement than the backlog item's own one-line description: navigation-model.md §4 already required the active (not-yet-held) cart to be continuously auto-persisted from the first item added, not only at an explicit "Hold" tap — satisfied by making `completeSale` update the existing draft/held row in place (same id, same provisional invoice number) rather than inserting a fresh row at payment time. Corrected schema-local.md's "Immutable event" classification for `sales`/`sale_line_items`/`sale_payments`, which cannot be literally true once a draft/held row is genuinely mutated pre-completion — now immutable only once `status` first becomes `'completed'`, mirroring schema-server.md's own trigger exactly. Resolved that the provisional invoice number is assigned once, at Draft creation, accepting gaps in the local provisional sequence from abandoned carts as a deliberate, named consequence, distinct from the canonical sequence's own stronger gapless guarantee. WF-006 (cancel) explicitly deferred, not part of this item's scope. |
| 0.10.0 | 2026-08-16 | Sprint 32 (backlog.md M3 item 2, Customers mobile): `POST /sales` gains an optional `customer_id`, validated against the caller's tenant when supplied (`NOT_FOUND` otherwise, the same `category_id`/`unit_id` existence-check shape products/service.ts already established) — see [customers/specification.md §1a](../customers/specification.md#1a-sprint-32--customers-mobile-m3-item-2) for the full mobile picker/attach design. |
| 0.10.1 | 2026-08-16 | Sprint 33 (backlog.md M3 item 3, Returns server): no request/response contract change — `pos/service.ts` gains two exports, `getCompletedSaleForReturn` (a read-only, `status = 'completed'`-only lookup) and `roundFraction` (the existing private BigInt-rounding helper, made public), both reused by `returnsService` via the sanctioned service-to-service path rather than a repository-layer reach-through — see [returns/specification.md §1](../returns/specification.md#1-purpose-and-business-context). |
