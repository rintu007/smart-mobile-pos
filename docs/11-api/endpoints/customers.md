# Endpoints — Customers

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Principal Next.js Engineer
> **Approved by:** _pending_

Covers `customers` ([schema-server.md](../../07-database/schema-server.md)'s Context 4) — the
smallest module in this API, deliberately: [scope-and-release-slices.md](../../01-vision/scope-and-release-slices.md)
keeps customer management minimal in V1 (name, phone, purchase lookup), not a full CRM.

---

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `GET /customers` | Any authenticated role | Read cached | N/A | Filter: `phone` (exact match — the return-by-phone lookup, [FR-062](../../03-functional-requirements/functional-requirements.md), and inline checkout search, [FR-052](../../03-functional-requirements/functional-requirements.md)). Cursor-paginated on `(updated_at, id)`. |
| `POST /customers` | Cashier, Manager, Owner | **Yes — queued** | Creation | Deliberately open to Cashier — a walk-in customer is captured inline during checkout, under queue pressure, and must not require a Manager to be present. |
| `PATCH /customers/{id}` | Cashier, Manager, Owner | Yes — queued | State-transition | |
| `DELETE /customers/{id}` | Manager, Owner | Yes — queued | State-transition | Soft delete; existing `sales.customer_id` references are set null on the *next* sale involving that customer, not retroactively — a completed sale's historical record is immutable regardless of the customer record's later state, per [sales.md](sales.md). |
| `GET /customers/{id}/purchase-history` | Any authenticated role | Read cached | N/A | Cursor-paginated list of the customer's `sales`, ordered `(completed_at, id)` desc — [FR-051](../../03-functional-requirements/functional-requirements.md). |

## Request/response shape — `POST /customers`

**Request**

```json
{ "id": "<client-generated UUIDv4>", "name": "Ramesh Kumar", "phone": "9876543210" }
```

Both `name` and `phone` are nullable at the schema level ([schema-server.md](../../07-database/schema-server.md))
— a Cashier may record just a phone number under time pressure and let the name be filled in later
via `PATCH`, or vice versa. The API does not require either field to be present, only that at least
one of the two is, so a customer record is never created with no way to ever look it up again.

**Response `201`**

```json
{
  "id": "<uuid>",
  "name": "Ramesh Kumar",
  "phone": "9876543210",
  "created_at": "2026-07-30T09:25:00Z",
  "updated_at": "2026-07-30T09:25:00Z"
}
```

## Errors specific to this module

| Code | HTTP | Cause |
| --- | --- | --- |
| `CUSTOMER_IDENTIFIER_REQUIRED` | 422 | Both `name` and `phone` omitted. |
| `PHONE_ALREADY_ASSIGNED` | 409 | `phone` collides with another active customer in the same tenant — the client is expected to search first (`GET /customers?phone=`) and reuse the existing record rather than create a duplicate; this error exists for the offline case where two devices independently create a customer with the same phone before either has synced (see [sync-api.md](../sync-api.md)'s conflict handling). |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial customer endpoint set: minimal CRM, phone lookup, purchase history. |
