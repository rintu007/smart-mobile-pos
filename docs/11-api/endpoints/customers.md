# Endpoints — Customers

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.3.0
> **Last updated:** 2026-08-19
> **Owner:** Principal Next.js Engineer
> **Approved by:** _pending_

Covers `customers` ([schema-server.md](../../07-database/schema-server.md)'s Context 4) — the
smallest module in this API, deliberately: [scope-and-release-slices.md](../../01-vision/scope-and-release-slices.md)
keeps customer management minimal in V1 (name, phone, purchase lookup), not a full CRM.

---

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `GET /customers` | Any authenticated role | Read cached | N/A | **Built Sprint 31**, live-verified (12/12). Filter: `phone` (exact match — the return-by-phone lookup, [FR-062](../../03-functional-requirements/functional-requirements.md), and inline checkout search, [FR-052](../../03-functional-requirements/functional-requirements.md)). Cursor-paginated on `(updated_at, id)`. Excludes deactivated customers, no query param to include them yet. |
| `POST /customers` | Cashier, Manager, Owner | Not yet — online-only this sprint (§ implementation note below) | Creation | **Built Sprint 31.** Deliberately open to Cashier — a walk-in customer is captured inline during checkout, under queue pressure, and must not require a Manager to be present. |
| `PATCH /customers/{id}` | Cashier, Manager, Owner | Not yet — online-only this sprint | State-transition | **Built Sprint 31**, plain last-write-wins — the conflict-resolution field-merge policy (§ implementation note) is separate, later scope. |
| `DELETE /customers/{id}` | Manager, Owner | Not yet — online-only this sprint | State-transition | **Built Sprint 31**, idempotent (live-verified). Soft delete; existing `sales.customer_id` references are set null on the *next* sale involving that customer, not retroactively — a completed sale's historical record is immutable regardless of the customer record's later state, per [sales.md](sales.md). |
| `POST /customers/{id}/erase` | **Owner only** | Not yet — online-only | State-transition | **Built Sprint 46** (`docs/12-security/privacy.md §4`). A genuine data-erasure request — stricter than `DELETE`'s Manager+Owner gate, since this is a data-governance/legal action, not an ordinary back-office one. Anonymises `name`/`phone` to `null` (the row/id survive, so historical `sales.customer_id` FKs stay valid); sets `deactivated_at` too if not already set. Idempotent — a second request on an already-erased customer is a no-op. |
| `GET /customers/{id}/purchase-history` | Any authenticated role | Read cached | N/A | **Built Sprint 31.** Cursor-paginated list of the customer's `sales`, ordered `(completed_at, id)` desc, `status = 'completed'` only — [FR-051](../../03-functional-requirements/functional-requirements.md). |

## Implementation note (Sprint 31, [customers/specification.md](../../modules/customers/specification.md))

Every write endpoint above is documented as offline-queued, but no `customer.create`/
`customer.update` sync-push operation type exists yet — same "table/endpoint exists, sync
integration is a separate, later item" shape Categories/Units/Trading Day's own online-only-creation
precedent already established. `customer.create` is [backlog.md M3 item 2](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point)'s
scope; `customer.update` — and the conflict-resolution field-merge policy `PATCH` needs to actually
honour concurrent offline edits — is item 5's scope. `POST /sales` does not yet accept
`customer_id`; that wiring is item 2's mobile-checkout scope, not this sprint's.

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
  "updated_at": "2026-07-30T09:25:00Z",
  "deactivated_at": null,
  "erased_at": null
}
```

`deactivated_at`/`erased_at` added Sprint 46 — present (nullable) on every customer object this
module returns, not only `POST /customers/{id}/erase`'s own response.

## Errors specific to this module

| Code | HTTP | Cause |
| --- | --- | --- |
| `CUSTOMER_IDENTIFIER_REQUIRED` | 422 | Both `name` and `phone` omitted. |
| `PHONE_ALREADY_ASSIGNED` | 409 | `phone` collides with another active customer in the same tenant — the client is expected to search first (`GET /customers?phone=`) and reuse the existing record rather than create a duplicate; this error exists for the offline case where two devices independently create a customer with the same phone before either has synced (see [sync-api.md](../sync-api.md)'s conflict handling). |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial customer endpoint set: minimal CRM, phone lookup, purchase history. |
| 0.2.0 | 2026-08-16 | All five endpoints built and live-verified (12/12) — Sprint 31, backlog.md M3 item 1. Online-only this sprint (no sync-push operation type yet, named explicitly); `POST /sales` does not yet accept `customer_id`. |
| 0.3.0 | 2026-08-19 | Sprint 46: `POST /customers/{id}/erase` built (privacy.md §4's already-designed anonymise-not-delete resolution, found unimplemented during Sprint 43's OWASP review). `deactivated_at`/`erased_at` added to every customer object's response shape — `deactivated_at` had never been exposed at all, a related gap found in the same pass. |
