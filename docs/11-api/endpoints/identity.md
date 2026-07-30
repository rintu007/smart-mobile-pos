# Endpoints — Identity & Tenancy

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Principal Next.js Engineer
> **Approved by:** _pending_

Covers `stores`, `users`, `user_store_roles`, `devices`, `audit_log`
([schema-server.md](../../07-database/schema-server.md)'s Context 1). Conventions
([error envelope](../error-catalogue.md), [pagination](../api-principles.md#4-pagination--cursor-only),
[idempotency](../api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation))
apply as stated in [api-principles.md](../api-principles.md); not repeated per row below.

---

## Stores

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `GET /stores` | Any authenticated role | Read cached, no queued write | N/A (read) | V1 always returns exactly one store per tenant — [ADR-0003](../../adr/ADR-0003-multi-outlet-modelled-from-day-one.md). No selector shown; the client uses the single result. |
| `PATCH /stores/{id}` | Owner | No — requires connectivity | State-transition mechanism (`client_operation_id`) | Name/address edits only; infrequent, back-office. |

## Users & roles

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `GET /users` | Manager, Owner | Read cached | N/A | Returns each user's current role per [user_store_roles](../../07-database/schema-server.md), filtered to non-revoked assignments. |
| `POST /users/invite` | Owner | No | Creation mechanism (client `id`) | Creates a pending user record; actual Supabase Auth identity is established when the invitee completes signup — this endpoint records intent, not a live account. |
| `PATCH /users/{id}/role` | Owner | No | State-transition | Writes a **new** `user_store_roles` row and sets `revoked_at` on the prior one — roles are versioned, never updated in place, per [DR-019](../../03-functional-requirements/business-rules.md)–[DR-021](../../03-functional-requirements/business-rules.md), preserving who-could-do-what-when for audit. |
| `DELETE /users/{id}` | Owner | No | State-transition | Sets `deactivated_at` (Tier 1 soft delete) — never a hard delete, per [ADR-0009](../../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md). |

## Devices

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `POST /auth/register-device` | Any authenticated user (self only) | No — this is the connectivity-establishing call itself | Creation mechanism (`client_device_id` is itself the natural dedup key — a second call with the same `client_device_id` updates `last_seen_at` rather than creating a duplicate row) | See [authentication.md §2](../authentication.md#2-issuance-flow). |
| `GET /devices` | Owner | Read cached | N/A | Device-revocation UI list, per [permission-matrix.md](../../05-personas/permission-matrix.md). |
| `PATCH /devices/{id}/revoke` | Owner | No | State-transition | See [authentication.md §5](../authentication.md#5-revocation-flow). Irreversible via this endpoint — a revoked device re-registers as a new device (§4 of [identifiers.md](../../07-database/identifiers.md)), never un-revokes. |

## Audit log

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `GET /audit-log` | Owner | Read cached (list is typically viewed back-office, online) | N/A | Cursor-paginated on `(tenant_id, created_at)`. Filters: `entity_type`, `entity_id`, `date_from`, `date_to`. This table is **never written to directly by any client-facing endpoint** — every mutating endpoint across every module writes its own audit row server-side as part of the same transaction as the business mutation, per [BR-009](../../02-business-requirements/business-requirements.md). There is no `POST /audit-log`. |

## Errors specific to this module

| Code | HTTP | Cause |
| --- | --- | --- |
| `DEVICE_REVOKED` | 401 | See [authentication.md §4](../authentication.md#4-device-binding-and-revocation--checked-on-every-request-not-only-at-token-mint). |
| `LAST_OWNER_CANNOT_BE_REMOVED` | 409 | `PATCH /users/{id}/role` or `DELETE /users/{id}` would leave the tenant with zero active Owners — rejected outright, since that is an unrecoverable lockout, not a business choice to allow. |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial identity/device/audit endpoint set. |
