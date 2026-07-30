# OWASP Checklist

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** Security Engineer / CTO
> **Approved by:** _pending_

OWASP Top 10 (2021, web/API) and OWASP Mobile Top 10, mapped to the mitigations already specified
across this phase and Phase 11 — a traceability check that nothing in these two well-known
checklists was missed, not a new set of controls invented here.

---

## OWASP Top 10 (2021)

| # | Category | This project's mitigation |
| --- | --- | --- |
| A01 | Broken Access Control | [authorisation-model.md](authorisation-model.md)'s 7-step fail-closed evaluation order; [tenant-isolation.md](tenant-isolation.md)'s dual API+RLS enforcement |
| A02 | Cryptographic Failures | TLS everywhere ([data-protection.md §1](data-protection.md#1-in-transit)); on-device SQLCipher encryption ([data-protection.md §3](data-protection.md#3-on-device-storage-encryption)); no raw payment data ever held ([RR-007](../02-business-requirements/regulatory-requirements.md)) |
| A03 | Injection | Structural: Prisma parameterisation, banned raw-SQL pattern ([input-validation.md §3](input-validation.md#3-sql-injection-is-a-structural-non-issue-not-a-discipline-one)) |
| A04 | Insecure Design | This entire 18-phase, design-before-code methodology — a threat model ([threat-model.md](threat-model.md)) produced before implementation, not retrofitted |
| A05 | Security Misconfiguration | Platform defaults relied on deliberately (TLS, at-rest encryption) rather than custom configuration that could be set wrong ([data-protection.md §§1–2](data-protection.md#1-in-transit)); RLS enabled unconditionally with no bypass flag ([tenancy-model.md §3](../07-database/tenancy-model.md#3-rls-is-never-bypassed-including-by-the-apis-own-connection)) |
| A06 | Vulnerable and Outdated Components | Dependency currency is a Phase 14/18 operational concern (automated dependency update tooling); [risk R-10](../01-vision/risks-constraints-assumptions.md) (dependency abandonment) already tracks the related risk of a chosen package losing maintenance |
| A07 | Identification and Authentication Failures | [identity-and-sessions.md](identity-and-sessions.md) — short access-token TTL, refresh rotation with reuse detection, rate-limited sign-in, no separate account-lockout DoS vector |
| A08 | Software and Data Integrity Failures | Idempotency keys prevent duplicate/replayed mutations ([api-principles.md §3](../11-api/api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation)); CI-gated migrations ([tenant-isolation.md §3](tenant-isolation.md#3-ci-enforcement--not-a-one-time-proof)) |
| A09 | Security Logging and Monitoring Failures | [audit-logging.md](audit-logging.md) — immutable, enumerated coverage of money/stock/permission actions; [incident-response.md §1](incident-response.md#1-detection)'s concrete alerting signals |
| A10 | Server-Side Request Forgery (SSRF) | No V1 feature accepts a server-fetched URL from client input (no webhook-URL configuration, no user-supplied image-fetch-by-URL) — not applicable to this API's current surface; revisit if a future feature (e.g. a V3 payment webhook) introduces one |

## OWASP Mobile Top 10

| # | Category | This project's mitigation |
| --- | --- | --- |
| M1 | Improper Credential Usage | Tokens in platform secure storage only, never shared preferences/plain files ([data-protection.md §3](data-protection.md#3-on-device-storage-encryption), this phase's exit criterion) |
| M2 | Inadequate Supply Chain Security | Free/open-source package selections made deliberately, with unverified-tooling specifics deferred to Phase 18 confirmation rather than committed on assumption (the standing pattern since [ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md)) |
| M3 | Insecure Authentication/Authorisation | Same as A07/A01 above — one model, not a separate mobile-specific one, since [authorisation-model.md](authorisation-model.md) is enforced server-side regardless of client platform |
| M4 | Insufficient Input/Output Validation | [input-validation.md](input-validation.md) — server-authoritative, client validation is UX-only |
| M5 | Insecure Communication | TLS, per A02 above |
| M6 | Inadequate Privacy Controls | [privacy.md](privacy.md) — inventory, lawful basis, anonymise-on-erasure |
| M7 | Insufficient Binary Protections | Assumed hostile by design, per this phase's rule and [threat-model.md](threat-model.md)'s TB-1 framing ("a decompiled client is assumed hostile") — no business logic or secret ever lives client-side to protect via obfuscation in the first place, which is a stronger guarantee than binary hardening would provide |
| M8 | Security Misconfiguration | Same as A05 |
| M9 | Insecure Data Storage | [data-protection.md §3](data-protection.md#3-on-device-storage-encryption) — SQLCipher-encrypted local database |
| M10 | Insufficient Cryptography | Platform-standard TLS and platform Keystore/Keychain-backed key storage — no custom cryptographic implementation exists anywhere in this project to get wrong |

## What this checklist confirms, and what it doesn't

Every category maps to an existing, already-specified control — **no new gap was found while
producing this table**, which is itself the value of doing it as a final cross-check rather than a
first-pass design exercise. It does not substitute for the actual verification work (the CI
cross-tenant suite running, the build-time secret scan catching something, a real penetration test
before commercial launch) — those are Phase 14/18 execution items this table points to, not replaces.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Full OWASP Top 10 and Mobile Top 10 traceability against this phase's and Phase 11's existing controls; no new gaps found. |
