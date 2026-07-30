# Audit Logging

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.1.1
> **Last updated:** 2026-07-31
> **Owner:** Security Engineer / CTO
> **Approved by:** _pending_

What is logged, the immutability mechanism, retention, and who may read it — the security-policy
layer over the `audit_log` table already schema-defined in
[schema-server.md](../07-database/schema-server.md).

---

## 1. What is logged

Every action that touches money, stock, or permissions — enumerated concretely, not left as a vague
"important events" statement, and bound exactly to [DR-025](../03-functional-requirements/business-rules.md)'s
formal rule: **every stock movement, sale, discount application, return, and role/permission change
produces exactly one corresponding `audit_log` entry, in the same transaction or queued operation as
the event itself** — restated here as this document's own binding requirement, not merely a
cross-reference, since it is directly testable per
[test-strategy.md §1](../14-testing/test-strategy.md#1-business-rule-traceability--the-exit-criterion-made-checkable).

| Category | Actions logged |
| --- | --- |
| Money | Sale completed, return decided (approved/rejected), trading day closed (with variance), settings change affecting tax/pricing/thresholds |
| Stock | **Every `stock_movements` row — `opening`, `sale`, `return`, and `adjustment` alike — gets exactly one paired `audit_log` entry, per DR-025.** *(Correction: this document's v0.1.0 draft understated this, treating the ledger's own append-only nature as sufficient and logging only adjustment decision-context — that reasoning is reasonable on its own terms but conflicts with DR-025's explicit, formally asserted 1:1 requirement, which takes precedence as an already-ratified Phase 03 business rule.)* |
| Permissions | Role granted/changed/revoked, device registered/revoked, user invited/deactivated |
| Catalogue | Product price change (the *old* and *new* price, in `before_state`/`after_state`) — a price is not itself a ledger fact, but a disputed price change is exactly the kind of thing that needs a "who changed what, when" answer |

**Not logged:** routine reads (a `GET /products` call), and anything already fully captured by its
own immutable record (`sales`, `returns`, `stock_movements` themselves) — logging a duplicate audit
row for every read of an append-only ledger would be volume without value.

## 2. Immutability — enforced at the grant level, not the application level

Per [schema-server.md](../07-database/schema-server.md), **no `UPDATE`/`DELETE` grant exists on
`audit_log` for any role, including the API's own service-role connection.** This is the same
pattern already applied to `stock_movements` ([ADR-0005](../adr/ADR-0005-append-only-stock-ledger.md))
— restated here as this phase's own exit criterion because it is a security property, not merely a
data-modelling one: an attacker who fully compromises the API's application code (not just a
request) still cannot alter or erase an audit trail, because the database itself refuses the
operation regardless of what the application asks it to do.

## 3. Retention

Audit records are retained indefinitely in V1 — there is no scheduled deletion job, consistent with
[ADR-0009](../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md)'s Tier 2
treatment. The specific minimum retention period a tax authority would require is, like the rest of
this project's tax-adjacent content, **pending the standing GST-practitioner review**
([docs/README.md](../README.md) tracks this as a cross-phase item) — "indefinite" satisfies any
finite minimum by construction, so this is a safe default to build against now, not a placeholder
guess that could later prove non-compliant.

## 4. Who may read it

**Owner only**, per [permission-matrix.md](../05-personas/permission-matrix.md) — a Manager does not
get audit-log read access, since the audit log's primary purpose includes recording Manager-level
actions (approvals, adjustments) for the Owner's oversight; giving Managers read access would
undermine exactly the accountability relationship the log exists to support. Enforced at
[authorisation-model.md](authorisation-model.md)'s step 5 (endpoint permission check), restated here
since it is this specific table's own access policy, not a generic rule.

## 5. What audit logging does not replace

This is a security/accountability trail, not an analytics or reporting data source — the daily
sales report ([FR-071](../03-functional-requirements/functional-requirements.md)) reads `sales`
directly, never `audit_log`. Conflating the two would either bloat the audit log with reporting-
driven query patterns it wasn't designed for, or tempt a future contributor into treating an
immutable security log as a place to derive business metrics, coupling two concerns that should stay
independent.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | What is logged, enumerated by category; immutability restated as a security property; Owner-only read access; retention deferred to the standing GST-review item, not guessed at. |
| 0.1.1 | 2026-07-31 | **Correction, found during Phase 14:** stock-movement logging brought into exact alignment with DR-025's 1:1 requirement — every movement gets a paired audit entry, not only adjustments. |
