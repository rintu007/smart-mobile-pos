# Module Specification — POS

> **Status:** 🟢 Approved
> **Module:** POS
> **Slice:** V1 — this document scopes only M0's minimal first cut, not the full V1 shape (§1)
> **Version:** 0.2.0
> **Last updated:** 2026-08-02
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

**Also out of scope this sprint:** the stock-ledger effect of a completed sale
([WF-002](../../06-workflows/sales-workflows.md#wf-002--complete-a-single-item-cash-sale) requires
it atomically with the sale, but [backlog.md item 7](../../17-sprints/backlog.md#1-m0--walking-skeleton-fully-decomposed)
("Stock ledger: opening movement on product creation, sale movement on sale completion... in the
same transaction as the sale") is its own, later backlog item, depending on this one. Between this
sprint landing and item 7 landing, a completed sale has no stock effect — an incremental-build gap,
named here rather than silently produced, matching how Sprint 02→03's Products/Categories/Units
split already worked the same way. The mobile till screen UI itself is also out of scope — see §4.

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
- No permission check beyond a valid, tenant-scoped session — Roles & Permissions is still M1 scope,
  the same named boundary Products' spec already states.

## 3. Database tables and relationships

`sales`, `sale_line_items`, `sale_payments`, per
[schema-server.md](../../07-database/schema-server.md) Context 5 — but, like Products (Sprint 04),
this sprint implements only a subset of each table's full column list.

`sales`: `id`, `tenant_id`, `store_id`, `status` (always `'completed'` this sprint),
`provisional_invoice_number`, `subtotal_minor_units`, `grand_total_minor_units`, `completed_at`,
`created_at`, `created_by`. **Not yet built:** `trading_day_id`, `device_id`, `customer_id`,
`canonical_invoice_number`, `tax_registration_type_at_sale`, `tax_total_minor_units`,
`discount_total_minor_units` — added once Trading Day/device-registration/Customers/tax-and-discount
(M1/M2) exist.

`sale_line_items`: `id`, `sale_id`, `product_id`, `quantity`, `unit_price_minor_units`,
`line_total_minor_units`. **Not yet built:** `variant_id`, `hsn_sac_code_at_sale`,
`tax_rate_basis_points`, `line_discount_minor_units`, `line_tax_minor_units`.

`sale_payments`: `id`, `sale_id`, `method` (constrained to `'cash'` this sprint —
[schema-server.md](../../07-database/schema-server.md)'s full `CHECK` also allows `card`/`other`,
kept in the constraint for forward-compatibility per [Products' precedent](../products/specification.md#3-database-tables-and-relationships)
of matching the eventual enum even before every value is reachable), `amount_minor_units`.

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

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/sales` | **Implemented this sprint.** Request: `{ id, store_id, provisional_invoice_number, line_items: [{ product_id, quantity, client_unit_price_minor_units }], payments: [{ method: "cash", amount_minor_units }] }` only — not the full shape [sales.md](../../11-api/endpoints/sales.md) documents (see that document's own dated correction note). Requires a valid tenant-scoped session (`requireSession`) — no role/permission check yet, no Trading Day precondition. |
| `GET /sales/{id}`, `GET /sales`, `GET /sales/lookup` | **Already documented**, not yet implemented — deferred past this sprint. |

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
| `payments` | Array, exactly length 1, required |
| `payments[].method` | Literal `"cash"`, required |
| `payments[].amount_minor_units` | Non-negative integer, required |

Server-side, beyond schema validation: every `product_id` must resolve to a real, non-deactivated
product in the caller's tenant (`NOT_FOUND` otherwise); each line's
`client_unit_price_minor_units` must equal the product's current `price_minor_units`
(`PRICE_MISMATCH` otherwise); `payments[0].amount_minor_units` must equal the computed
`grand_total_minor_units` exactly (`PAYMENT_AMOUNT_MISMATCH` otherwise).

## 6. Error handling and user-facing messages

`VALIDATION_FAILED` (422) for schema failures, `NOT_FOUND` (404) for an unknown `product_id` — both
already cross-cutting codes in [error-catalogue.md](../../11-api/error-catalogue.md), reused as-is
rather than inventing module-specific equivalents. `PRICE_MISMATCH` (409, already catalogued) for a
stale cached price. `PAYMENT_AMOUNT_MISMATCH` (409) is new this sprint — added to
[error-catalogue.md](../../11-api/error-catalogue.md). None of these codes are reachable from the
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

**Explicitly deferred:** `GET /sales*`, the stock-ledger effect (backlog.md item 7), the sync engine
that would actually drain `outbound_queue` and exercise this endpoint's error codes from a real
device (item 9), receipt printing (item 10), everything the full V1 contract requires beyond M0's
minimal shape (§1).

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [FR-024](../../03-functional-requirements/functional-requirements.md) (single-item cash sale in ≤3 actions) | §9 | **Partially met** — the till screen exists and a single-item cash sale is tap-product, tap-complete (2 taps); no formal tap-count audit against patterns.md has been run, matching how [route-map.md](../../09-navigation/route-map.md)'s own audit process works for other screens |
| [FR-042](../../03-functional-requirements/functional-requirements.md) (completing a sale records a negative stock-ledger entry) | — | **Not met** — stock ledger is backlog.md item 7, a later sprint (§1) |
| [WF-002](../../06-workflows/sales-workflows.md#wf-002--complete-a-single-item-cash-sale) (single-item cash sale workflow) | §2, §5, §9 | **Partially met** — the server recompute/payment-validation half (Sprint 05) and the mobile local-write half (Sprint 09) are both built; the two are not yet connected (no sync engine), and the atomic sale+stock-movement transaction (§1) is not built |
| [api-principles.md §7](../../11-api/api-principles.md#7-the-server-recomputes-it-never-trusts-a-client-figure) (server recomputes, never trusts a client figure) | §2, §5 | Met |
| [ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md) (client-generated UUID PKs, idempotent creation) | §2 | Met |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-01 | First version — written to drive Sprint 05's implementation of `POST /api/v1/sales`. Scope deliberately narrow (cash-only, no trading day/device/tax/discount); the stock-ledger effect and the mobile till screen both named as not-yet-met rather than silently claimed. |
| 0.2.0 | 2026-08-02 | Sprint 09: mobile till screen (`/pos`) and its local write path built — cart, cash-only completion, `sales`/`sale_line_items`/`sale_payments` + `outbound_queue` written atomically, ADR-0008's local invoice-numbering half implemented as a deliberately narrower slice (no `devices` row, no canonical-number assignment). The server endpoint and the mobile write path are proven independently; nothing yet drains `outbound_queue` to connect them (backlog.md item 9). |
