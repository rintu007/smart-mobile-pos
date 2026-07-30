# Threat Model

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Security Engineer / CTO
> **Approved by:** _pending_

STRIDE analysis applied to each of the 8 trust boundaries [system-context.md §4](../04-srs/system-context.md#4-trust-boundaries--the-list-phase-12-inherits)
already enumerated — this document is where "Phase 12 inherits this list" is made good on, boundary
by boundary, with a named mitigation for every applicable STRIDE category. A boundary with a STRIDE
category silently skipped is exactly the gap this phase's exit criterion exists to prevent.

---

## How to read this document

**S**poofing, **T**ampering, **R**epudiation, **I**nformation disclosure, **D**enial of service,
**E**levation of privilege. Not every category applies to every boundary (e.g. Repudiation is not
meaningful for a read-only subscription) — where a category is inapplicable, that is stated
explicitly, never left as a blank cell that could be mistaken for an oversight.

## TB-1 — Mobile client → API

| STRIDE | Threat | Mitigation |
| --- | --- | --- |
| Spoofing | A forged or replayed JWT claiming another user's identity | Supabase-signed JWT, verified on every request; short access-token TTL ([authentication.md](../11-api/authentication.md)) bounds replay window |
| Tampering | A decompiled client sends a manipulated price/tax/total | Server recomputes and compares — never trusts the client figure ([api-principles.md §7](../11-api/api-principles.md#7-the-server-recomputes-it-never-trusts-a-client-figure)) |
| Repudiation | A user denies having performed a completed sale/return/adjustment | `audit_log` records every such action server-side, immutably ([audit-logging.md](audit-logging.md)) — never dependent on client-side logging, which an attacker controls |
| Information disclosure | An endpoint response leaks another tenant's data | Tenant scoping enforced twice — API repository layer and RLS ([tenant-isolation.md](tenant-isolation.md)) |
| Denial of service | A scripted client floods a mutating endpoint | Per-device/per-tenant rate limiting ([rate-limiting.md](../11-api/rate-limiting.md)) |
| Elevation of privilege | A Cashier-role token used to call a Manager/Owner-only endpoint | Server-side role check on every endpoint, evaluated before any handler logic runs ([authorisation-model.md](authorisation-model.md)) |

## TB-2 — Mobile client → Supabase Realtime

| STRIDE | Threat | Mitigation |
| --- | --- | --- |
| Spoofing | N/A beyond TB-4 (same JWT) | — |
| Tampering | N/A — read-only channel, no client write path exists here at all | — |
| Repudiation | N/A — nothing is "done" via a subscription | — |
| Information disclosure | **The load-bearing risk on this entire threat model** — a missing or incorrect RLS policy leaks cross-tenant data directly over a channel with no API layer in front of it | RLS is the **sole** gate; [tenant-isolation.md §4](tenant-isolation.md#4-extending-the-cross-tenant-proof-to-realtime) extends the automated cross-tenant negative-test suite to this channel specifically, not merely to table access via the API |
| Denial of service | A client opens excessive concurrent subscriptions | Supabase connection-count limits at the platform level; not a custom control this project builds |
| Elevation of privilege | N/A — a subscription cannot mutate state | — |

## TB-2b — Mobile client → Supabase Storage

| STRIDE | Threat | Mitigation |
| --- | --- | --- |
| Spoofing | A client requests a signed URL for a file it shouldn't access | The API issues the signed URL only after its own tenant/permission check — the client never obtains a storage credential directly |
| Tampering | A signed upload URL is reused to overwrite a different file | Signed URLs are scoped to one object key and short-lived |
| Information disclosure | A leaked signed URL exposes one file | Bounded — short expiry window, one object only, per [system-context.md](../04-srs/system-context.md)'s stated "Medium" severity for this boundary |
| Denial of service | Repeated signed-URL issuance requests | Covered by the general API rate limiting on the issuing endpoint |
| Elevation of privilege | N/A | — |

## TB-3 — API → Postgres

| STRIDE | Threat | Mitigation |
| --- | --- | --- |
| Spoofing | N/A — a trusted server-to-server connection, not a client-facing boundary | — |
| Tampering | A SQL injection via unparameterised query construction | Prisma parameterises every query by construction; raw SQL string concatenation is a banned pattern enforced by lint rule ([input-validation.md §3](input-validation.md#3-sql-injection-is-a-structural-non-issue-not-a-discipline-one)) |
| Repudiation | N/A — covered at TB-1, the point where the originating action is attributed to a user | — |
| Information disclosure | The service-role credential itself leaking would bypass every API-level check | Secrets-management discipline ([secrets-management.md](secrets-management.md)) — this is why RLS ([tenant-isolation.md](tenant-isolation.md)) is never bypassed even for this trusted connection, per [ADR-0004](../adr/ADR-0004-shared-schema-multi-tenancy.md) — defence in depth assumes this credential *could* leak |
| Denial of service | Connection exhaustion under load | Connection pooling, load-tested at 10× peak ([rate-limiting.md §3](../11-api/rate-limiting.md#3-connection-pooling--the-r-07-mitigation-load-tested-before-ga)) |
| Elevation of privilege | N/A | — |

## TB-4 — Client/API → Supabase Auth

| STRIDE | Threat | Mitigation |
| --- | --- | --- |
| Spoofing | Credential stuffing / brute-force login attempts | Per-account and per-IP rate limits on sign-in ([rate-limiting.md §1](../11-api/rate-limiting.md#1-limits-by-endpoint-class)) |
| Tampering | A client attempts to inject its own `tenant_id` claim | The claim is set exclusively server-side at token mint via the Custom Access Token Hook — never accepted as client input ([tenancy-model.md §1](../07-database/tenancy-model.md#1-how-a-request-knows-which-tenant-it-is)) |
| Repudiation | N/A | — |
| Information disclosure | A stolen refresh token used to mint new access tokens indefinitely | Refresh-token rotation with reuse detection ([identity-and-sessions.md §3](identity-and-sessions.md#3-refresh-token-reuse-detection)) |
| Denial of service | N/A beyond the spoofing-mitigation rate limits above | — |
| Elevation of privilege | N/A — role is resolved from `user_store_roles`, not carried in a client-influenced claim | — |

## TB-5 — Mobile client → Bluetooth printer

| STRIDE | Threat | Mitigation |
| --- | --- | --- |
| Spoofing / Tampering | A rogue paired device intercepts or garbles print output | Out of scope for a meaningful mitigation beyond OS-level Bluetooth pairing, per [system-context.md](../04-srs/system-context.md)'s "Low" severity rating — receipt content is not confidential in the way credentials are |
| Information disclosure | A receipt shows a customer's name/phone | Accepted — a printed receipt showing the customer it belongs to is expected, ordinary behaviour, not a leak |
| Denial of service / Elevation of privilege | N/A | — |

## TB-6 — API → Payment gateway (future, V3)

Deferred per [system-context.md](../04-srs/system-context.md) — "not yet applicable." Flagged here,
not modelled in detail, so this document is revisited (not silently assumed already covered) when
V3 payment integration is actually scoped.

## TB-7 — Physical device ↔ its own local database

| STRIDE | Threat | Mitigation |
| --- | --- | --- |
| Spoofing | N/A — this boundary is about data at rest, not authentication | — |
| Tampering | A local attacker with the device modifies cached data to defraud the shop before the next sync | The server never trusts client-submitted figures on sync either — the same [api-principles.md §7](../11-api/api-principles.md#7-the-server-recomputes-it-never-trusts-a-client-figure) recompute-and-compare rule applies to a synced operation exactly as it does to a live one |
| Repudiation | N/A | — |
| Information disclosure | A lost/stolen device exposes cached business and customer data | Local database encryption at rest ([data-protection.md §3](data-protection.md#3-on-device-storage-encryption)); tokens in platform secure storage, never the SQLite file itself |
| Denial of service | N/A | — |
| Elevation of privilege | A stolen device's session used to act as its user indefinitely | Remote device revocation, checked on every API request ([authentication.md §4](../11-api/authentication.md#4-device-binding-and-revocation--checked-on-every-request-not-only-at-token-mint)) |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Full STRIDE pass across all 8 trust boundaries; every applicable category given a named, cross-referenced mitigation. |
