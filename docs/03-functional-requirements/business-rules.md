# Business Rules

> **Status:** 🔵 In review
> **Phase:** 03 — Functional Requirements
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** CTO / Business Analyst
> **Approved by:** _pending_

26 domain rules (`DR-001`–`DR-026`) — the logic that holds true regardless of which screen,
platform, or API version touches it. Per this phase's exit criterion, each is written so it can
become a unit test **verbatim**: given inputs, an assertion. These rules, not the functional
requirements, are where "stock", "tax", "return", and "permission" are actually defined.

Where a rule constrains the schema (Phase 07) or the sync engine (Phase 13), that is noted — these
rules are inputs to those phases, not a substitute for them.

---

## Stock

**DR-001.** A product's current stock balance at a store equals the sum of `quantity_delta` across
all its stock-ledger movements at that store. It is never read from, or written to, any separately
stored balance field.
> `assert balance(product, store) == sum(m.quantity_delta for m in movements(product, store))`

**DR-002.** A stock-ledger movement, once created, is never updated or deleted by any code path.
> `assert update(movement) raises` and `assert delete(movement) raises`, for every movement
> regardless of age or origin.

**DR-003.** Completing a sale of quantity `Q` for product `P` creates exactly one stock-ledger
movement with `quantity_delta = -Q`, referencing the sale.
> `assert count(movements where reference == sale.id) == 1` and
> `assert that movement.quantity_delta == -Q`

**DR-004.** Completing a return of quantity `Q` for product `P` creates exactly one stock-ledger
movement with `quantity_delta = +Q`, referencing both the return and the original sale.
> `assert movement.quantity_delta == +Q` and `assert movement.references == {return.id, original_sale.id}`

**DR-005.** A sale is permitted to complete even when it would take a product's derived balance
below zero. The system never blocks a sale on insufficient recorded stock.
> `assert complete_sale(product_with_balance=0, quantity=1).succeeds == true`

**DR-006.** An opening-stock movement establishes the first recorded balance for a product+store
combination; it is not used to correct an existing balance — corrections use a stock adjustment
(DR-007) instead.
> `assert opening_stock movement type is distinct from adjustment movement type in the schema`

**DR-007.** A stock adjustment movement requires a `reason` drawn from a fixed, non-empty list; a
movement without one is rejected before it is persisted.
> `assert create_adjustment(reason=null) raises validation_error`

## Tax and money

**DR-008.** Tax on a sale is computed per line item: `line_tax = round(line_taxable_value ×
tax_rate, shop.rounding_rule)`. The invoice-level tax total is the sum of already-rounded line
taxes, never a value independently rounded from the invoice total.
> `assert invoice.total_tax == sum(line.tax for line in invoice.lines)` — never
> `round(sum(line.taxable_value for line in invoice.lines) × tax_rate)`

**DR-009.** A Composition-scheme or unregistered shop's issued sale document contains no
input-credit tax breakup and is typed as a Bill of Supply, not a Tax Invoice.
> `assert document_type(shop.tax_status == 'composition').type == 'bill_of_supply'`

**DR-010.** Every monetary value, from calculation through storage to display, is represented as an
integer count of the currency's minor unit. No monetary value is ever represented, stored, or
computed as a floating-point number at any point in the pipeline.
> `assert typeof(any_money_field) in {integer, minor_unit_integer}` — a floating-point monetary
> value anywhere in the pipeline is a defect, not a rounding nuance.

**DR-011.** A discount is expressed as either a percentage or a fixed minor-unit amount on a given
line — never both simultaneously.
> `assert not (line.discount_percent != null and line.discount_amount != null)`

**DR-012.** A discount whose effective value exceeds the shop's configured auto-approval threshold
requires a Manager-role (or higher) approval before the sale containing it can complete.
> `assert complete_sale(discount > threshold, approver=null) raises requires_approval`

## Returns eligibility

**DR-013.** A return line item's quantity must not exceed the original sale line's quantity minus
any quantity already returned against that same line.
> `assert return_quantity <= original_line.quantity - sum(prior_returns.quantity)`

**DR-014.** A return line's refund amount equals the original line's per-unit price — inclusive of
its tax portion — multiplied by the returned quantity.
> `assert refund_amount == original_line.unit_price_incl_tax × returned_quantity`

**DR-015.** A return whose total refund value exceeds the shop's configured return-approval
threshold cannot complete without Manager-role (or higher) approval.
> `assert complete_return(refund_value > threshold, approver=null) raises requires_approval`

**DR-016.** A return references exactly one original sale. A single return record cannot span line
items from more than one original sale.
> `assert return.original_sale_id is a single value, never a set`

## Permissions

**DR-017.** Every permission check is evaluated server-side at the time an operation is actually
applied (at sync, for offline-originated operations) — never trusted from client-reported state.
> `assert server_apply(operation) re-checks permission independent of any client-supplied "authorized" flag`

**DR-018.** An operation failing its server-side permission check at sync time is rejected in full;
partial application of a rejected operation never occurs.
> `assert rejected_operation.applied_effects == []`

**DR-019.** A Cashier-role user may: complete a sale, hold/resume a sale, apply a discount up to the
shop's auto-approval threshold. A Cashier-role user may not: change tax configuration, void a
completed sale, or approve a return/discount above threshold.
> One `assert` per listed allow/deny pair, exercised against a Cashier-role principal.

**DR-020.** A Manager-role user holds every Cashier-role permission, plus: discount/return approval
above threshold, stock adjustment, and day-close override.
> Permission set for Manager is a strict superset of Cashier's, plus the listed additions —
> asserted by set inclusion, not by re-listing Cashier's permissions.

**DR-021.** An Owner-role user holds every Manager-role permission, plus: user and role management,
and settings configuration.
> Permission set for Owner is a strict superset of Manager's, plus the listed additions.

## Synchronisation and idempotency

**DR-022.** Every mutating operation carries a client-generated idempotency key. The server applies
an operation's effect at most once per unique key, regardless of how many times it is retried or
resubmitted.
> `assert apply(op, key) then apply(op, key) again → effect_count == 1`

**DR-023.** A stock-ledger `quantity_delta` recorded by one device is never adjusted, scaled, or
overwritten based on another device's concurrent movement. Deltas from different devices are always
additive.
> `assert balance_after(deviceA.delta, deviceB.delta) == balance_before + deviceA.delta + deviceB.delta`,
> for any ordering of arrival.

**DR-024.** A sale's provisional (offline-assigned) invoice number is permanent once assigned. It is
never replaced or renumbered after sync; a server-issued canonical number, if any, is stored as an
additional reference alongside it, never in its place.
> `assert sale.provisional_invoice_number after sync == sale.provisional_invoice_number before sync`

## Audit

**DR-025.** Every stock movement, sale, discount application, return, and role/permission change
produces exactly one corresponding audit-log entry, created within the same transaction or queued
operation as the event itself.
> `assert count(audit_entries for event) == 1` and `assert audit_entry.transaction_id == event.transaction_id`

**DR-026.** No stored procedure, API endpoint, or administrative tool can update or delete an
existing audit-log row.
> `assert update(audit_entry) raises` and `assert delete(audit_entry) raises`, exercised against
> every code path that has database access, not only the public API.

---

## Traceability

Every rule above supports one or more functional requirements in
[functional-requirements.md](functional-requirements.md) and feeds directly into
[07-database](../07-database/README.md) (schema constraints) and
[13-offline-sync](../13-offline-sync/README.md) (DR-022, DR-023, DR-024 specifically). The
consolidated view is in [traceability-matrix.md](traceability-matrix.md).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial 26 domain rules across stock, tax/money, returns, permissions, sync, and audit. |
