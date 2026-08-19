# Phase 12 — Security Design

> **Status:** 🔵 In review — all 11 deliverables drafted
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** Security Engineer / CTO

## Charter

| | |
| --- | --- |
| **Objective** | Define the security model across identity, authorisation, tenant isolation, data protection and auditing — and prove the isolation holds. |
| **Inputs** | Phases 07 and 11 (both 🔵 In review). [OD-02](../01-vision/open-decisions.md) resolved (Option B — [ADR-0002](../adr/ADR-0002-hosting-posture-for-commercial-launch.md)) and [OD-03](../01-vision/open-decisions.md) resolved (Option C — [ADR-0001](../adr/ADR-0001-hybrid-api-and-direct-realtime-access.md)). |

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`threat-model.md`](threat-model.md) | Full STRIDE pass across all 8 trust boundaries from [system-context.md](../04-srs/system-context.md) | 🔵 In review |
| [`identity-and-sessions.md`](identity-and-sessions.md) | Token lifetimes justified, reuse detection, multi-device stance, precisely-scoped revocation guarantee | 🔵 In review |
| [`authorisation-model.md`](authorisation-model.md) | 7-step fail-closed evaluation order, 4-layer enforcement table | 🔵 In review |
| [`tenant-isolation.md`](tenant-isolation.md) | 22-table verification checklist; cross-tenant proof extended to Realtime | 🔵 In review |
| [`data-protection.md`](data-protection.md) | SQLCipher on-device encryption built, Sprint 48; encryption-vs-unsynced-data trade-off stated | 🔵 In review |
| [`input-validation.md`](input-validation.md) | Reject-not-coerce policy; SQL injection/path traversal/XSS closed structurally | 🔵 In review |
| [`audit-logging.md`](audit-logging.md) | Logged-actions enumeration, grant-level immutability, Owner-only read | 🔵 In review |
| [`secrets-management.md`](secrets-management.md) | Secret inventory, two-mechanism build-time no-leak verification | 🔵 In review |
| [`privacy.md`](privacy.md) | Personal data inventory, provisional DPDPA basis, anonymise-on-erasure reconciling ADR-0009 | 🔵 In review |
| [`incident-response.md`](incident-response.md) | Detection signals, containment mapped to existing mechanisms, backup/PITR tied to OD-02's open budget | 🔵 In review |
| [`owasp-checklist.md`](owasp-checklist.md) | Full Top 10 + Mobile Top 10 traceability — no new gaps found | 🔵 In review |

## Exit criteria

- [x] Every trust boundary is threat-modelled with named mitigations —
      [threat-model.md](threat-model.md), all 8 boundaries, every applicable STRIDE category covered.
- [x] **Automated tests prove cross-tenant access fails on every table**, not a sample —
      [tenant-isolation.md §2](tenant-isolation.md#2-what-every-table-means-precisely-restated-as-a-checklist)
      accounts for all 22 tables by category; §3 restates the CI-gate gating every migration.
- [x] Authorisation is enforced server-side on every endpoint; client checks are UX only —
      [authorisation-model.md §3](authorisation-model.md#3-enforcement-points--three-not-one-deliberately-redundant)
      states this explicitly per layer.
- [x] No secret can reach a client bundle; verified by a build-time check —
      [secrets-management.md §3](secrets-management.md#3-the-build-time-check--the-exit-criterions-actual-mechanism)'s
      two independent mechanisms (import-boundary CI rule, bundle content scan).
- [x] Tokens are stored in platform secure storage, never shared preferences —
      [data-protection.md §3](data-protection.md#3-on-device-storage-encryption); restated in
      [owasp-checklist.md](owasp-checklist.md)'s M1 row.
- [x] Audit log is append-only and cannot be modified by any application code path —
      [audit-logging.md §2](audit-logging.md#2-immutability--enforced-at-the-grant-level-not-the-application-level) —
      enforced at the database grant level, holding even against a fully compromised application.
- [x] A lost or stolen device can have its sessions revoked server-side —
      [identity-and-sessions.md §5](identity-and-sessions.md#5-revocation--the-security-guarantee-restated-precisely) —
      a hard guarantee for the API, honestly bounded (not instant) for Realtime.
- [x] Rate limiting protects authentication, sync and any endpoint that can enumerate data —
      already specified in [rate-limiting.md](../11-api/rate-limiting.md), restated as a security
      control in [threat-model.md](threat-model.md)'s TB-1/TB-3/TB-4 rows.
- [x] Personal data can be exported and deleted on request —
      [privacy.md §4](privacy.md#4-deletion--reconciling-erasure-rights-with-ledger-immutability)
      (anonymise, not hard-delete, reconciling [ADR-0009](../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md))
      and §5 (export payload fully assemblable from existing endpoints).

All nine exit criteria are met by design. Per this documentation set's standing practice, this means
**the mechanisms and proofs are specified correctly**, not that CI is green on a running system yet
— the cross-tenant test suite, the secret-scanning build step, and the connection-pool load test
([rate-limiting.md §3](../11-api/rate-limiting.md#3-connection-pooling--the-r-07-mitigation-load-tested-before-ga))
all require Phase 18 implementation to actually execute, tracked forward rather than assumed passed.

## Rules

- **Defence in depth.** Tenant isolation is enforced in the API *and* at the database. We assume
  each layer will eventually be got wrong; the isolation guarantee must survive that.
- Fail closed. An authorisation check that errors denies access.
- The offline database on the device is assumed to be readable by an attacker who has the device.
  Design accordingly — that is why cached data is scoped and why tokens live in secure storage.
- Security findings block release. There is no "ship it and patch next sprint" for this category.
