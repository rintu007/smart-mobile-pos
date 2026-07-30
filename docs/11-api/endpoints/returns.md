# Endpoints — Returns

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Principal Next.js Engineer
> **Approved by:** _pending_

Covers `returns`, `return_line_items` ([schema-server.md](../../07-database/schema-server.md)'s
Context 6), implementing [WF-012/WF-013](../../06-workflows/returns-workflows.md) and the approval
interrupt/queue split from [tap-count-audit.md](../../09-navigation/tap-count-audit.md).

---

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `POST /returns` | Cashier, Manager, Owner | **Yes — queued** | Creation | Below the auto-approval threshold ([shop_settings.return_auto_approval_threshold_minor_units](../../07-database/schema-server.md)), created directly at `status = 'completed'`. Above it, created at `status = 'pending_approval'`. |
| `GET /returns/{id}` | Cashier, Manager, Owner | Read cached | N/A | Returns with `line_items` embedded, matching [sales.md](sales.md)'s aggregate convention. |
| `GET /returns` | Manager, Owner (store-wide); Cashier (own device only) | Read cached | N/A | Filter: `status`. Cursor-paginated on `(created_at, id)`. |
| `GET /returns/approvals` | Manager, Owner | Read cached | N/A | `status = pending_approval` only — the approval queue behind the Reports-tab badge, per [navigation-model.md](../../09-navigation/navigation-model.md). |
| `POST /returns/{id}/approve` | Manager, Owner | Yes — queued (see note) | State-transition (`client_operation_id`) | See note below on the interrupt-path/queue-path split. |
| `POST /returns/{id}/reject` | Manager, Owner | Yes — queued | State-transition | Requires `reason` in the body — shown to the Cashier per [voice-and-tone.md](../../10-design-system/voice-and-tone.md)'s "state the concrete problem" rule, never a bare rejection. |

## Request/response shape — `POST /returns`

**Request**

```json
{
  "id": "<client-generated UUIDv4>",
  "original_sale_id": "<uuid>",
  "line_items": [
    { "original_sale_line_item_id": "<uuid>", "quantity": "1.000" }
  ]
}
```

`refund_amount_minor_units` per line and `refund_total_minor_units` overall are **computed
server-side** from the original sale's line pricing — per
[api-principles.md §7](../api-principles.md#7-the-server-recomputes-it-never-trusts-a-client-figure)
and [DR-014](../../03-functional-requirements/business-rules.md); the client never submits a refund
amount. The server also checks the cumulative-quantity-already-returned constraint
([DR-013](../../03-functional-requirements/business-rules.md), backed by the index on
`return_line_items.original_sale_line_item_id`) before accepting any line.

**Response `201`** (auto-approved case)

```json
{
  "id": "<uuid>",
  "original_sale_id": "<uuid>",
  "status": "completed",
  "refund_total_minor_units": 2800,
  "line_items": [ { "original_sale_line_item_id": "<uuid>", "quantity": "1.000", "refund_amount_minor_units": 2800 } ],
  "completed_at": "2026-07-30T09:40:00Z"
}
```

Above the threshold, the same response shape is returned with `"status": "pending_approval"` and
`"completed_at": null`.

## The approve endpoint's two paths, and why offline capability differs between them

Per [tap-count-audit.md](../../09-navigation/tap-count-audit.md), a return needing approval has two
distinct paths: **interrupt** (a Manager is present and online at the moment of the return, and
approves in the current screen) and **queue** (no Manager available; it waits in
`GET /returns/approvals`). Both call the same `POST /returns/{id}/approve` endpoint — the split is a
navigation/timing distinction, not a different API contract. It is genuinely offline-capable (a
Manager can approve from the queue while their own device is offline, queuing the approval itself
for sync) but **the requesting Cashier's device only reflects the approval once it has synced** —
until then, the return sits at `pending_approval` from that device's point of view, which is the
correct, honest state per [state-presentation.md](../../10-design-system/state-presentation.md)'s
offline rules, not a bug to hide.

## Errors specific to this module

| Code | HTTP | Cause |
| --- | --- | --- |
| `RETURN_QUANTITY_EXCEEDS_SOLD` | 409 | Cumulative returned quantity for a line would exceed what was originally sold. |
| `RETURN_ALREADY_DECIDED` | 409 | `approve`/`reject` attempted on a return not in `pending_approval`. |
| `ORIGINAL_SALE_NOT_FOUND` | 404 | `original_sale_id` does not resolve — includes the case where the sale exists but has not yet synced from another device; the client is expected to retry once its next pull sync completes, per [sync-api.md](../sync-api.md). |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial returns endpoint set: threshold-based auto-approval, interrupt/queue approval paths on one shared endpoint. |
