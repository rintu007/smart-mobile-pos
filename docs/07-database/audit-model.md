# Audit Model

> **Status:** 🔵 In review
> **Phase:** 07 — Database Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** PostgreSQL Architect / Security Engineer
> **Approved by:** _pending_

The `audit_log` table itself is specified in [schema-server.md](schema-server.md); its
tamper-resistance mechanism (no `UPDATE`/`DELETE` grant, for any role) is specified there and in
[ADR-0009](../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md). This
document covers what triggers an entry, what's stored, who can read it, and retention.

---

## 1. What triggers an audit entry

Every action listed in [DR-025](../03-functional-requirements/business-rules.md) — restated here as
a concrete, exhaustive list against actual V1 actions:

| Action | Entity type | Trigger |
| --- | --- | --- |
| Stock movement recorded (any type) | `stock_movement` | Every row insert into `stock_movements` |
| Sale completed | `sale` | Transition to `status = 'completed'` |
| Sale cancelled | `sale` | Transition to `status = 'cancelled'` |
| Discount applied above auto-approval threshold | `sale` | The approval decision itself, attributing the approving Manager |
| Return completed | `return` | Transition to `status = 'completed'` |
| Return approved / rejected | `return` | The approval decision |
| Trading day opened / closed / reopened | `trading_day` | Each state transition ([state-machines.md](../06-workflows/state-machines.md)) |
| Role assigned or revoked | `user_store_role` | Insert or `revoked_at` set |
| Device session revoked | `device` | `revoked_at` set |
| Settings changed | `shop_settings` | Any update — tax mode, thresholds, currency |
| User created or deactivated | `user` | Insert or `deactivated_at` set |

**One entry per triggering event, written in the same transaction/queued operation as the event
itself** — per [DR-025](../03-functional-requirements/business-rules.md), never as a separate,
later, best-effort write that could be silently dropped.

## 2. What is stored per entry

Per [schema-server.md](schema-server.md)'s `audit_log` columns: `actor_user_id` (who),
`action`/`entity_type`/`entity_id` (what), `created_at` (when — server time, per
[assumptions-and-dependencies.md](../04-srs/assumptions-and-dependencies.md), never trusting device
clocks for this), and `before_state`/`after_state` as `JSONB` snapshots.

**What is deliberately excluded from `before_state`/`after_state`:** any field that would itself be
a secret or sensitive credential (there are none among V1's audited entities, but this is stated as
a standing rule for every future entity added to the audited list, not just a current fact) — per
[NFR-015](../03-functional-requirements/non-functional-requirements.md), no secret reaches any
log, including this one.

## 3. Who can read it

Per the [permission matrix](../05-personas/permission-matrix.md): **Owner and Manager**, not
Cashier. A Manager reviewing shift activity has an operational reason to see it; a Cashier reviewing
the audit log — which may reference other staff's actions and approval decisions — has no
operational need, per the same restrictive-by-default reasoning applied to
[BR-005](../02-business-requirements/business-requirements.md)'s device-revocation permission.

Read access goes through the API only (TB-1) — the audit log is **not** synced to devices as a
readable local cache, per [schema-local.md](schema-local.md); it is a reporting/oversight surface,
viewed online, not a till feature.

## 4. Retention

**Not yet resolved — an open item, not silently assumed.** Financial/audit retention periods are
typically set by tax law, and [regulatory-requirements.md](../02-business-requirements/regulatory-requirements.md)
already flags "confirm invoice/record retention period under Indian tax law" as an open item
pending the standing GST-practitioner review. Until that's confirmed:

- **No automatic deletion or archival of `audit_log` rows exists in V1** — the table simply grows,
  consistent with [ADR-0009](../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md)'s
  "no delete path" rule for ledger/event data, and already priced into
  [cost-model.md](../02-business-requirements/cost-model.md)'s long-run storage projections.
- Once the retention period is confirmed, an **archival** strategy (move old rows to cheaper
  storage) may be introduced — but this is explicitly an archival/performance decision, not a
  deletion one; the "no delete" invariant on the primary record does not change, per
  [ADR-0009](../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md)'s own
  "revisit when" clause.

## 5. What this model does not cover

Application-level logging (crash reports, performance telemetry) is a separate concern, owned by
[12-security/audit-logging.md](../12-security/audit-logging.md) — this document
covers only the business-event audit trail, the one [BR-009](../02-business-requirements/business-requirements.md)
requires.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial audit model: trigger list, stored fields, read-access restriction, retention flagged as pending regulatory confirmation. |
