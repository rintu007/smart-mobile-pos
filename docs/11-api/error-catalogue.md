# Error Catalogue

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.1.11
> **Last updated:** 2026-08-21
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
| `UNAUTHENTICATED` | 401 | No valid session token presented — covers a missing token and an expired/malformed/otherwise-invalid one identically; `core/auth/session.ts` never distinguishes *why* `auth.getUser(token)` rejected a token, only that it did | The mobile client retries once after a silent `refreshSession()` call ([authentication.md §3](authentication.md#3-token-lifetimes-and-refresh)); force sign-in only if that refresh itself also fails — this is the common real-world case (an access token that expired while the device was offline), not a distinct server-side code. |
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
| `PAYMENT_AMOUNT_MISMATCH` | 409 | A submitted payment's total does not equal the server-recomputed `grand_total_minor_units` — [sales.md](endpoints/sales.md) | Refresh the computed total and prompt the Cashier to confirm the payment amount before retrying. |
| `STOCK_ANOMALY` | — (not a rejection; informational, surfaced via `sync_rejections`, never blocks a sale) | A resulting stock balance went negative — expected under concurrent offline selling, per [stock-ledger.md](../07-database/stock-ledger.md) | No client action required; visible to the Owner via the `sync_rejections`-backed attention list. |

## Module-specific codes (defined in their owning document, indexed here for completeness)

| Code | Module |
| --- | --- |
| `LAST_OWNER_CANNOT_BE_REMOVED`, `ALREADY_ONBOARDED`, `EMAIL_ALREADY_REGISTERED` | [identity.md](endpoints/identity.md) |
| `CATEGORY_IN_USE`, `BARCODE_ALREADY_ASSIGNED`, `SKU_ALREADY_ASSIGNED`, `UNIT_FRACTIONAL_FLAG_LOCKED` | [catalogue.md](endpoints/catalogue.md) |
| `ADJUSTMENT_REASON_REQUIRED`, `DIRECT_SALE_MOVEMENT_FORBIDDEN` | [inventory.md](endpoints/inventory.md) |
| `CUSTOMER_IDENTIFIER_REQUIRED`, `PHONE_ALREADY_ASSIGNED`, `CONFLICT_RESOLUTION_VALUE_INVALID` | [customers.md](endpoints/customers.md) |
| `TRADING_DAY_NOT_OPEN`, `TRADING_DAY_ALREADY_OPEN`, `TRADING_DAY_NOT_CLOSED`, `SALE_IMMUTABLE`, `DISCOUNT_REQUIRES_APPROVAL` | [sales.md](endpoints/sales.md) |
| `RETURN_QUANTITY_EXCEEDS_SOLD`, `RETURN_ALREADY_DECIDED`, `ORIGINAL_SALE_NOT_FOUND` | [returns.md](endpoints/returns.md) |
| `RECEIPT_TEMPLATE_MISSING_MANDATORY_FIELD`, `SETTINGS_CONFLICT`, `TAX_RATE_REQUIRES_STANDARD_MODE` | [settings.md](endpoints/settings.md) |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial catalogue: 9 cross-cutting codes, sync/financial-integrity codes, index of module-specific codes. |
| 0.1.1 | 2026-07-31 | Added `SETTINGS_CONFLICT` (defined by Phase 13's conflict-resolution policy) to the module-specific index — changelog corrected to actually reflect this, since the code had already been added to the table without a version bump. |
| 0.1.2 | 2026-08-01 | Added `ALREADY_ONBOARDED` (defined by identity.md's new Onboarding section) to the module-specific index. |
| 0.1.3 | 2026-08-01 | Added `PAYMENT_AMOUNT_MISMATCH` (financial-integrity code, defined by Sprint 05's M0-minimal `POST /sales`). |
| 0.1.4 | 2026-08-14 | Added `SKU_ALREADY_ASSIGNED` to the module-specific index — Sprint 19's `(tenant_id, sku)` unique constraint on `products` needed the same treatment `BARCODE_ALREADY_ASSIGNED` already got, rather than surfacing as an unhandled 500. |
| 0.1.5 | 2026-08-14 | Sprint 23: `PERMISSION_DENIED` and `LAST_OWNER_CANNOT_BE_REMOVED` (both already reserved) implemented for the first time. Added `EMAIL_ALREADY_REGISTERED` to the module-specific index — `POST /users/invite`'s own Supabase-Admin duplicate-email rejection needed a named code, the same pattern `BARCODE_ALREADY_ASSIGNED`/`SKU_ALREADY_ASSIGNED` already set. |
| 0.1.6 | 2026-08-14 | Sprint 25: `SETTINGS_CONFLICT` (already reserved) implemented for the first time. Added `TAX_RATE_REQUIRES_STANDARD_MODE` to the module-specific index — `PATCH /settings`'s own rejection of a nonzero tax rate outside `tax_mode: 'standard'` (settings/specification.md §5/§6). |
| 0.1.7 | 2026-08-14 | Sprint 26: `TRADING_DAY_ALREADY_OPEN` (already reserved) implemented for the first time; `TRADING_DAY_NOT_OPEN` (already reserved) partially implemented — reachable only when `POST /sales`'s optional `trading_day_id` is supplied and invalid, not when omitted (trading-day/specification.md §1). Added `TRADING_DAY_NOT_CLOSED` to the module-specific index. |
| 0.1.8 | 2026-08-14 | Sprint 27: added `DISCOUNT_REQUIRES_APPROVAL` to the module-specific index — `POST /sales`'s rejection of an over-threshold discount with no valid Manager/Owner approval (DR-012, pos/specification.md §2/§6). |
| 0.1.9 | 2026-08-16 | Sprint 35: added `CONFLICT_RESOLUTION_VALUE_INVALID` to the module-specific index — `POST /customers/conflicts/{id}/resolve`'s rejection of a `resolved_value` matching neither of the conflict's own two candidate values (customers/specification.md §1c/§6). |
| 0.1.10 | 2026-08-20 | Sprint 55: `DEVICE_REVOKED` (already reserved) implemented for the first time — `requireSession`'s per-request device-revocation check, `authentication.md §4`. |
| 0.1.11 | 2026-08-21 | Sprint 57: found `TOKEN_EXPIRED` was never actually implementable as a distinct code — `core/auth/session.ts`'s JWT verification never checks *why* a token was rejected, only that it was, so every invalid-token case (missing, malformed, or expired) has always surfaced as plain `UNAUTHENTICATED`. Removed the row; its client-handling guidance (silent refresh, retry once) folded into `UNAUTHENTICATED`'s own row instead, now that the mobile client actually implements it. |
