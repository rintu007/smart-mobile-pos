# Error Catalogue

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.1.1
> **Last updated:** 2026-07-31
> **Owner:** Principal Next.js Engineer
> **Approved by:** _pending_

Every machine-readable `error.code` used anywhere in this API, in one flat namespace, per
[api-principles.md §6](api-principles.md#6-error-envelope). Per this phase's exit criterion,
**clients never parse `error.message`** — they switch on `code` here and select the actual
on-screen wording from [voice-and-tone.md](../10-design-system/voice-and-tone.md). Module-specific
codes are also listed in their owning [endpoints/](endpoints/) document; this catalogue is the
single complete list, not a duplicate source of truth — module documents link here, not the reverse.

---

## Cross-cutting codes (any endpoint)

| Code | HTTP | Cause | Client handling |
| --- | --- | --- | --- |
| `VALIDATION_FAILED` | 422 | Request body fails schema validation (missing/malformed field) | Show the field-level message from `details`; never a generic "something went wrong." |
| `UNAUTHENTICATED` | 401 | No valid session token presented | Force sign-in. |
| `TOKEN_EXPIRED` | 401 | Access token past expiry | Silent refresh via the refresh token ([authentication.md](authentication.md)); only surfaced to the user if refresh itself also fails. |
| `DEVICE_REVOKED` | 401 | See [authentication.md §4](authentication.md#4-device-binding-and-revocation--checked-on-every-request-not-only-at-token-mint) | Force local sign-out; **never** clear the local unsynced-sales queue. |
| `PERMISSION_DENIED` | 403 | Authenticated, but the user's role lacks this action per [permission-matrix.md](../05-personas/permission-matrix.md) | Route to the permission-denied pattern, [patterns.md §6](../10-design-system/patterns.md#6-permission-denied) — this should be rare, since [guards-and-redirects.md](../09-navigation/guards-and-redirects.md) already prevents most of these client-side; a live occurrence usually means a role changed mid-session. |
| `NOT_FOUND` | 404 | No resource matches the given ID within the caller's tenant scope | Note: a resource belonging to a *different* tenant also returns `NOT_FOUND`, never a distinguishable "exists but not yours" — see [tenancy-model.md §5](../07-database/tenancy-model.md#5-the-proof-automated-cross-tenant-negative-test-suite)'s existence-leakage concern. |
| `IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD` | 409 | The same `id`/`client_operation_id` was submitted with materially different content than the first time it was seen | This is a genuine client bug (an ID must never be reused for a different logical operation, per [identifiers.md §5](../07-database/identifiers.md#5-edge-case--idempotency-keys-are-identifiers-too)), not a normal retry — logged distinctly from an ordinary idempotent replay. |
| `RATE_LIMITED` | 429 | See [rate-limiting.md](rate-limiting.md) | Respect the `Retry-After` header; never retry in a tight loop. |
| `INTERNAL` | 500 | Unhandled server-side failure | Generic retry-or-contact-support treatment per [state-presentation.md §3](../10-design-system/state-presentation.md#3-error); the specific cause is logged server-side, never included in `message`. |

## Sync-specific codes ([sync-api.md](sync-api.md))

| Code | HTTP (per-operation result, not the batch's own status) | Cause | Client handling |
| --- | --- | --- | --- |
| `DEPENDENCY_NOT_FOUND` | — | See [sync-api.md §4](sync-api.md#4-why-dependency_not_found-is-not-not_found) | Leave the operation queued; resubmit on the next push cycle, do not discard. |

## Financial-integrity codes

| Code | HTTP | Cause | Client handling |
| --- | --- | --- | --- |
| `PRICE_MISMATCH` | 409 | Connected-device sale submitted against a stale cached price — [sales.md](endpoints/sales.md) | Refresh the product's price and prompt the Cashier to confirm before retrying; this error is **not** produced for offline-queued sales, which complete using the price actually charged. |
| `STOCK_ANOMALY` | — (not a rejection; informational, surfaced via `sync_rejections`, never blocks a sale) | A resulting stock balance went negative — expected under concurrent offline selling, per [stock-ledger.md](../07-database/stock-ledger.md) | No client action required; visible to the Owner via the `sync_rejections`-backed attention list. |

## Module-specific codes (defined in their owning document, indexed here for completeness)

| Code | Module |
| --- | --- |
| `LAST_OWNER_CANNOT_BE_REMOVED` | [identity.md](endpoints/identity.md) |
| `CATEGORY_IN_USE`, `BARCODE_ALREADY_ASSIGNED`, `UNIT_FRACTIONAL_FLAG_LOCKED` | [catalogue.md](endpoints/catalogue.md) |
| `ADJUSTMENT_REASON_REQUIRED`, `DIRECT_SALE_MOVEMENT_FORBIDDEN` | [inventory.md](endpoints/inventory.md) |
| `CUSTOMER_IDENTIFIER_REQUIRED`, `PHONE_ALREADY_ASSIGNED` | [customers.md](endpoints/customers.md) |
| `TRADING_DAY_NOT_OPEN`, `TRADING_DAY_ALREADY_OPEN`, `SALE_IMMUTABLE` | [sales.md](endpoints/sales.md) |
| `RETURN_QUANTITY_EXCEEDS_SOLD`, `RETURN_ALREADY_DECIDED`, `ORIGINAL_SALE_NOT_FOUND` | [returns.md](endpoints/returns.md) |
| `RECEIPT_TEMPLATE_MISSING_MANDATORY_FIELD`, `SETTINGS_CONFLICT` | [settings.md](endpoints/settings.md) |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial catalogue: 9 cross-cutting codes, sync/financial-integrity codes, index of module-specific codes. |
| 0.1.1 | 2026-07-31 | Added `SETTINGS_CONFLICT` (defined by Phase 13's conflict-resolution policy) to the module-specific index — changelog corrected to actually reflect this, since the code had already been added to the table without a version bump. |
