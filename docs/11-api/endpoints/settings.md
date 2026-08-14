# Endpoints — Settings

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.2.0
> **Last updated:** 2026-08-14
> **Owner:** Principal Next.js Engineer
> **Approved by:** _pending_

Covers `shop_settings` ([schema-server.md](../../07-database/schema-server.md)'s Context 7) — one
row per tenant, so this module has no list endpoint and no client-generated ID at all.

---

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `GET /settings` | Any authenticated role (read scope varies — see below) | Read cached | N/A | The mobile client caches this aggressively; it is read on nearly every screen (tax mode for pricing display, printer config for receipts). **Built Sprint 25.** |
| `PATCH /settings` | Owner only | No — requires connectivity | State-transition (`client_operation_id`) | Deliberately **not** offline-queued, unlike most of this API — see below. **Built Sprint 25**, minus `printer_config`/`receipt_template_config` (deferred, see the implementation note below). |

## Implementation note (Sprint 25, [settings/specification.md](../../modules/settings/specification.md))

**A default `shop_settings` row is now written in the same onboarding transaction** as
`tenants`/`stores`/`users`/the bootstrap `owner` role (`identity/repository.ts`'s `createOnboarding`)
— per seed-data.md's own named "safest universal default": `tax_mode: 'unregistered'`,
`tax_rate_basis_points: 0`, `pricing_mode: 'inclusive'`, `rounding_rule: 'round_half_up'`,
`currency_code: 'INR'`, both auto-approval thresholds at ₹500/₹1,000. Business-type-based
per-vertical seeding (seed-data.md's fuller design) remains a named, deferred gap — onboarding
collects no business-type field.

**A real gap in the underlying Phase 07 design, found and corrected the same day:**
[schema-server.md](../../07-database/schema-server.md) never actually named where
[DR-008](../../03-functional-requirements/business-rules.md)'s `tax_rate` comes from.
`shop_settings` gains `tax_rate_basis_points` — a single shop-wide flat rate (forced to `0` outside
`tax_mode: 'standard'`, [DR-009](../../03-functional-requirements/business-rules.md)), not a
per-product/per-HSN slab-rate table. See [money-and-tax.md §2a](../../07-database/money-and-tax.md#2a-where-tax_rate_basis_points-comes-from-correction-found-2026-08-14-decomposing-m2).

`PATCH /settings` rejects `printer_config`/`receipt_template_config` if present in the request body
at all (`422 VALIDATION_FAILED`), rather than silently accepting or ignoring them — no
printer-pairing or receipt-template-editing flow exists yet to give either field real content.
Whole-row optimistic concurrency (`base_updated_at` vs. the row's own `updated_at`) is implemented
exactly as this document already specified — a stale value produces `SETTINGS_CONFLICT`.

## Why `PATCH /settings` is the one mutating endpoint that is not offline-capable

Every other mutating endpoint in this API is offline-queued because the underlying action
(a sale, a stock count, a new customer) is safe to apply later without needing the *current* server
state to make sense of it. Tax mode, pricing mode, and approval thresholds are different: they are
read by **every other queued operation** to determine correctness (a sale's tax calculation depends
on `tax_mode` at the moment it's applied). Allowing this to be queued and changed offline would mean
a backlog of queued sales might need to be evaluated against a settings value that was still in
flux locally — a correctness risk with no proportionate benefit, since an Owner changing tax
registration status is an infrequent, deliberate, back-office action that can reasonably require
being online. This is a deliberate, narrow exception to this phase's general offline-first stance,
not an oversight.

## Field-level read scope

| Field | Visible to |
| --- | --- |
| `tax_mode`, `pricing_mode`, `rounding_rule`, `currency_code` | Everyone — needed by the POS pricing display itself |
| `discount_auto_approval_threshold_minor_units`, `return_auto_approval_threshold_minor_units` | Manager, Owner only — a Cashier does not need to know the exact threshold that would trigger an approval requirement, which would otherwise invite gaming it |
| `printer_config`, `receipt_template_config` | Everyone — needed by the printing flow on any device |

`GET /settings` therefore returns a **role-shaped response**, not one fixed shape with fields
omitted client-side — the server never sends a Cashier's device a field it isn't entitled to see at
all, consistent with [permission-matrix.md](../../05-personas/permission-matrix.md)'s stance that
permission is enforced server-side, never merely hidden in the UI.

## Request/response shape — `PATCH /settings`

**Request** (partial update; only changed fields included)

```json
{ "client_operation_id": "<uuid>", "tax_mode": "standard", "pricing_mode": "inclusive" }
```

**Response `200`** — the full, role-shaped `GET /settings` response reflecting the change.

## Errors specific to this module

| Code | HTTP | Cause |
| --- | --- | --- |
| `RECEIPT_TEMPLATE_MISSING_MANDATORY_FIELD` | 422 | `receipt_template_config` attempts to disable a legally mandatory field — enforced at the service layer per [BR-049](../../02-business-requirements/business-requirements.md), restated here since it is this endpoint's own rejection path. **Not yet reachable** — `PATCH /settings` rejects `receipt_template_config` entirely this sprint (see the implementation note above), so this code has no live path until that deferral lifts. |
| `SETTINGS_CONFLICT` | 409 | The request's base `updated_at` no longer matches the current row — a concurrent `PATCH /settings` landed first. Whole-row reject-and-retry, never merged — see [conflict-resolution.md §4](../../13-offline-sync/conflict-resolution.md#4-the-one-deliberate-exception--shop_settings-does-not-field-merge). **Built and live-verified Sprint 25.** |
| `TAX_RATE_REQUIRES_STANDARD_MODE` | 422 | **New, Sprint 25.** A nonzero `tax_rate_basis_points` combined with a resulting `tax_mode` that isn't `'standard'` — per [DR-009](../../03-functional-requirements/business-rules.md). |
| `SETTINGS_CHANGE_REQUIRES_CONNECTIVITY` | N/A (client-side only — the client never attempts this call offline in the first place) | Documented for completeness; this is a client behaviour, not a server error response. |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial settings endpoint set; deliberate non-offline exception explained; role-shaped read scope specified. |
| 0.1.1 | 2026-07-31 | Added `SETTINGS_CONFLICT`, defined by Phase 13's conflict-resolution policy. |
| 0.2.0 | 2026-08-14 | Sprint 25 (backlog.md M2 item 1): `GET`/`PATCH /settings` built and live-verified (26/26); a default `shop_settings` row now written at onboarding. Added `tax_rate_basis_points` (a dated correction to schema-server.md/money-and-tax.md — DR-008's tax rate never had a named source). Added `TAX_RATE_REQUIRES_STANDARD_MODE`. `printer_config`/`receipt_template_config` explicitly deferred — `PATCH /settings` rejects either with `VALIDATION_FAILED` rather than accepting them. |
