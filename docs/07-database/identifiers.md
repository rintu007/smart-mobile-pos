# Identifiers

> **Status:** 🔵 In review
> **Phase:** 07 — Database Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** PostgreSQL Architect
> **Approved by:** _pending_

Consolidates the identifier strategy across every entity type. The two significant decisions —
primary key generation and offline invoice numbering — are ratified in
[ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md) and
[ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md); this document is the operational detail
those ADRs don't cover, including two edge cases neither ADR addresses on its own.

---

## 1. Primary keys — summary

Every table's `id` (or, for entities that are also idempotency keys, `client_operation_id` doubling
as `id`) is a client-generated UUIDv4, per [ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md).
Server-originated rows (e.g. `tenants`, created during signup) use the same UUIDv4 generation,
server-side — one convention, no special cases.

## 2. Business-meaningful identifiers (not primary keys)

| Identifier | Table | Uniqueness scope | Notes |
| --- | --- | --- | --- |
| `sku` | `products` | Per tenant, nullable | Optional; a product is sellable without one via search ([FR-034](../03-functional-requirements/functional-requirements.md)). |
| `barcode` | `products` | Per tenant, nullable | The latency-critical lookup path ([NFR-002](../03-functional-requirements/non-functional-requirements.md)); indexed in [schema-server.md](schema-server.md). |
| `provisional_invoice_number` | `sales` | Per device, per financial year | See §3. |
| `canonical_invoice_number` | `sales` | Per tenant, per financial year | See §3. |
| `client_device_id` | `devices` | Per user | Client-generated at install; see §4 for why this must never be reused. |

## 3. Invoice numbering — financial-year rollover

[ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md) fixes the scheme; this section fixes what
happens at the financial-year boundary (April 1, for the provisional India market — provisional
like everything else tied to [OD-01](../01-vision/open-decisions.md)).

- **Provisional numbers** are keyed by `(device, financial_year)` in the local
  `local_provisional_sequence` table ([schema-local.md](schema-local.md)) — the sequence
  automatically starts fresh at `1` for a new financial year, since it's keyed by year, not reset by
  a scheduled job that could itself fail or run late.
- **Canonical numbers** are keyed by `(tenant_id, financial_year)` server-side — same principle,
  no explicit "reset" operation exists to forget to run; a new financial year simply has no rows yet
  in that keyspace.
- A sale straddling the boundary (created just before midnight, synced just after) is assigned its
  canonical number based on **sync time**, not sale time — consistent with
  [ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md)'s sync-arrival-order rule, and flagged
  again here since financial-year boundaries are exactly where this distinction becomes visible on
  a real invoice. **Also pending the standing GST-practitioner review.**

## 4. Edge case — device reinstallation must not reuse a provisional-number namespace

If a device's app is reinstalled (or the device is factory-reset), a naive implementation might
regenerate the same `client_device_id` (e.g. from a hardware identifier) and reset
`local_provisional_sequence` to zero — producing a **second sale with the same
`provisional_invoice_number`** as one already issued before the reset. This would violate the
permanence guarantee in [ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md).

**Resolution:** `client_device_id` is generated fresh, locally, at each app installation — never
derived from a stable hardware identifier. A reinstalled app is, by design, treated as a new device
with a new provisional-numbering namespace, even if it's physically the same phone. The old device
row in `devices` is not reused; it simply stops being seen (and can be revoked, per
[BR-005](../02-business-requirements/business-requirements.md), if the reinstall was due to loss/
resale rather than routine app maintenance).

## 5. Edge case — idempotency keys are identifiers too

Per [DR-022](../03-functional-requirements/business-rules.md), `client_operation_id` is not merely a
primary key — it is the mechanism that makes a retried creation safe. This means **the ID must be
generated once, at the moment of user action, and reused verbatim on every retry of that same
action** — a retry that generates a *new* UUID for "the same" sale would defeat the entire purpose.
This is an implementation discipline for Phase 18 (the mobile client must not regenerate an ID on
retry), stated here because it is an identifier-strategy consequence, not a UI detail.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial consolidation. Two edge cases resolved: device-reinstall numbering collision, retry-must-reuse-ID discipline. |
