# OWASP Checklist

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.3.0
> **Last updated:** 2026-08-19
> **Owner:** Security Engineer / CTO
> **Approved by:** _pending_

OWASP Top 10 (2021, web/API) and OWASP Mobile Top 10, mapped to the mitigations already specified
across this phase and Phase 11 — a traceability check that nothing in these two well-known
checklists was missed, not a new set of controls invented here.

---

## Sprint 43 (backlog.md M4 item 8) — this table walked against the real build, not the design docs

The v0.1.0 table below was a **design-time** traceability check — every category cited another
design document as its own evidence, and concluded "no new gap was found," which that version's own
closing section admitted was expected of a first-pass design exercise, not a substitute for "the
actual verification work." This version is that verification, done for the first time: every row
re-checked directly against `apps/web/src`, `apps/mobile/lib`, `supabase/sql/*.sql`, and the real CI
workflows — not the docs that cite them. Four real gaps were serious enough to fix in this same pass
(marked **Fixed, Sprint 43** below); the rest are named, dated, and — where they carry real
production risk — flagged for the founder rather than silently deferred.

### The two most important findings, stated plainly before the table

1. **Row-level security is very likely inert for all real production traffic today — the "defence
   in depth" second layer this project's entire tenant-isolation model depends on may not actually
   exist.** `apps/web/src/core/db/client.ts`'s singleton Prisma connection never issues `SET LOCAL
   ROLE`/`SET LOCAL request.jwt.claims` — confirmed by grep, zero occurrences anywhere in
   `apps/web/src`. Every one of the 19 real tables has `ENABLE ROW LEVEL SECURITY`
   (`supabase/sql/002`–`018`), but **none has `FORCE ROW LEVEL SECURITY`** — confirmed by grep,
   zero occurrences anywhere in `supabase/sql/`. Postgres exempts a table's own **owner** from its
   RLS policies regardless of `ENABLE`, unless `FORCE` is also set; the role that runs `prisma
   migrate deploy` (the same `DATABASE_URL` the running app uses) becomes the owner of every table
   it creates. Unless the real production `DATABASE_URL` role is deliberately *not* the table owner
   — something this repository cannot confirm, since that's a live Supabase project configuration,
   not code — `current_tenant_id()` (which reads `auth.jwt() ->> 'tenant_id'`, itself backed by
   `request.jwt.claims`, a setting nothing in this codebase ever sets on this connection) would
   resolve to `NULL` on every query, and RLS would either do nothing (owner-exempt) or block
   everything (if somehow enforced with no claim set) — the application demonstrably works in
   production, which is only consistent with the owner-exempt, RLS-inert case. **This is not fixed
   in this PR.** Adding `FORCE ROW LEVEL SECURITY` blindly, without first confirming the real
   production role, risks a full production outage (every tenant-scoped query suddenly returning
   zero rows) — this needs the founder to confirm the actual `DATABASE_URL` role Supabase issued
   before any change is made, the same category of "needs information only production access has"
   as the branch-protection setting Sprint 40 also could not apply itself.
2. **No request-throttling code existed anywhere in this repository — fixed Sprint 45, with one
   real architectural limit found while building it.** `rate-limiting.md`'s mutating/read/sync-push
   classes are now enforced inside `requirePermission` (a Postgres-backed fixed-window counter, no
   external service — `core/rate-limit/`), verified against a real database. The **Auth class
   (sign-in/OTP) cannot be implemented in this codebase at all** — found while trying to wire it up:
   sign-in is a direct client call to Supabase Auth (`docs/modules/authentication/specification.md`
   §1a), never reaching an `apps/web` Route Handler, so `identity-and-sessions.md §6`'s "repeated
   failed sign-in attempts are throttled" claim can only ever be true via Supabase Auth's own
   platform-side configuration — a project setting, not code this repository can add. Whether that
   platform-level throttling is actually active has not been separately confirmed and remains a
   real, named gap (see `rate-limiting.md`'s own Sprint 45 correction).

## OWASP Top 10 (2021)

| # | Category | This project's mitigation | Verified status |
| --- | --- | --- | --- |
| A01 | Broken Access Control | [authorisation-model.md](authorisation-model.md)'s 7-step fail-closed evaluation order; [tenant-isolation.md](tenant-isolation.md)'s dual API+RLS enforcement | **PARTIAL.** `requireSession`/`requirePermission` (`core/auth/session.ts`) genuinely fail closed — confirmed by reading the code, not assumed. RLS is enabled on all 19 real tables, but see finding #1 above: the "dual, independent" claim is unproven and likely false for the API's own connection today. Device-revocation (authorisation-model.md's step 2) has no `devices` table and is unimplemented — an already-named gap (identity-and-sessions.md §4/§5 describes the intended guarantee; no code delivers it), not new to this review. |
| A02 | Cryptographic Failures | TLS everywhere ([data-protection.md §1](data-protection.md#1-in-transit)); on-device SQLCipher encryption ([data-protection.md §3](data-protection.md#3-on-device-storage-encryption)); no raw payment data ever held ([RR-007](../02-business-requirements/regulatory-requirements.md)) | **PARTIAL.** No card/PAN/payment-instrument fields exist anywhere in the schema — confirmed. TLS is a Vercel/Supabase platform default, nothing in this codebase weakens it. On-device encryption is a **GAP** — see M9 below, same finding, not restated twice. |
| A03 | Injection | Structural: Prisma parameterisation, banned raw-SQL pattern ([input-validation.md §3](input-validation.md#3-sql-injection-is-a-structural-non-issue-not-a-discipline-one)) | **CONFIRMED.** The only raw SQL in the whole codebase (`integration-tests/cross-tenant-isolation.test.ts`) interpolates only hardcoded internal identifiers from a fixed array, with real values passed as bound parameters — no production code path builds SQL from untrusted input. |
| A04 | Insecure Design | This entire 18-phase, design-before-code methodology — a threat model ([threat-model.md](threat-model.md)) produced before implementation, not retrofitted | **CONFIRMED** (process claim, verified against `git log`'s own chronology — the repository's first commit already references pre-existing phase docs it implements). |
| A05 | Security Misconfiguration | Platform defaults relied on deliberately; RLS enabled unconditionally with no bypass flag ([tenancy-model.md §3](../07-database/tenancy-model.md#3-rls-is-never-bypassed-including-by-the-apis-own-connection)) | **PARTIAL, one piece Fixed Sprint 43.** No committed secrets (`.env.example` only). No CORS config exists (mobile uses Bearer tokens, not cross-origin cookies — largely moot). `next.config.ts` had zero explicit security headers — **fixed this sprint** (`poweredByHeader: false`, `X-Content-Type-Options`/`X-Frame-Options`/`Referrer-Policy`). "RLS has no bypass flag" is technically true (no role has `BYPASSRLS` set) but, per finding #1, misses the table-owner exemption, which has the same practical effect — tracked there, not double-counted here. |
| A06 | Vulnerable and Outdated Components | Dependency currency is a Phase 14/18 operational concern | **CONFIRMED.** `.github/dependabot.yml` (Sprint 42) is real and complete — npm/pub/github-actions, weekly. |
| A07 | Identification and Authentication Failures | [identity-and-sessions.md](identity-and-sessions.md) — short access-token TTL, refresh rotation with reuse detection, rate-limited sign-in, no separate account-lockout DoS vector | **PARTIAL, mostly Fixed Sprint 45.** Mutating/read/sync-push rate limiting now built (finding #2 above) — see [rate-limiting.md](../11-api/rate-limiting.md). Sign-in specifically remains a **GAP**: architecturally unreachable from this codebase (sign-in never touches `apps/web`), needs Supabase's own platform-side configuration, unconfirmed. Token TTL/rotation/reuse-detection are real but entirely a Supabase Auth platform default this codebase neither implements nor separately tests — a legitimate architectural choice (identity-and-sessions.md §2 says so explicitly), just not something this repo's own code proves. |
| A08 | Software and Data Integrity Failures | Idempotency keys prevent duplicate/replayed mutations; CI-gated migrations | **CONFIRMED.** Idempotency verified in depth across Sprints 40/41/43 (including a real concurrency-race fix). `fast-integration`'s `prisma migrate deploy` step genuinely runs before any test. |
| A09 | Security Logging and Monitoring Failures | [audit-logging.md](audit-logging.md) — immutable, enumerated coverage of money/stock/permission actions; [incident-response.md §1](incident-response.md#1-detection)'s concrete alerting signals | **Two real gaps, both found this sprint; the audit-coverage one Fixed Sprint 43.** DR-025 ("every stock movement... produces exactly one corresponding audit-log entry") was unimplemented for 3 of 4 `stock_movements` types (`opening`/`sale`/`return` — only the summary `sale.completed`/`return.completed` entries existed, not one per movement row) and entirely unimplemented for the 4th (`adjustment`) and for settings changes — despite `audit-logging.md`'s own Phase 14 v0.1.1 correction already specifying the per-row requirement, and `implementation-log.md`'s Sprint 12 entry already naming stock-movement audit coverage as "a real, still-open gap" that was never subsequently closed. **Fixed this sprint** across `products/repository.ts`, `pos/repository.ts`, `returns/repository.ts` (both its auto-approval and manual-approval paths), `stock-movements/repository.ts`, and `settings/repository.ts` — verified for real against a real database (`integration-tests/audit-log-coverage.test.ts`). Alerting/monitoring infrastructure (Sentry or equivalent) is a **GAP, not fixed** — zero code or config exists anywhere; `incident-response.md` itself already says this is a future Phase 18 item, not a claim of present coverage. |
| A10 | Server-Side Request Forgery (SSRF) | No V1 feature accepts a server-fetched URL from client input | **CONFIRMED.** Zero `fetch(` calls anywhere in `apps/web/src` outside tests. |

## OWASP Mobile Top 10

| # | Category | This project's mitigation | Verified status |
| --- | --- | --- | --- |
| M1 | Improper Credential Usage | Tokens in platform secure storage only, never shared preferences/plain files | **GAP, not fixed this pass.** `flutter_secure_storage` is a `pubspec.yaml` dependency but is **never imported or used anywhere** in `apps/mobile/lib` — confirmed by grep. `Supabase.initialize()` (`main.dart`) passes no custom `localStorage`, so the session/JWT falls back to `supabase_flutter`'s default `SharedPreferences`-backed storage — plaintext on Android, not Keychain/Keystore-backed. Wiring `flutter_secure_storage` in is real, bounded mobile work, but changes how existing installs store their session — needs a considered migration, not a same-pass patch. |
| M2 | Inadequate Supply Chain Security | Free/open-source package selections made deliberately | **CONFIRMED** (informational spot check — `pubspec.yaml`/`package.json` dependencies are all actively-maintained, mainstream packages). |
| M3 | Insecure Authentication/Authorisation | Same as A01/A07 — one model, not a separate mobile-specific one | **CONFIRMED**, same caveats as A01/A07 (mobile calls the identical Bearer-token endpoints as every other client; no separate/weaker path exists). |
| M4 | Insufficient Input/Output Validation | [input-validation.md](input-validation.md) — server-authoritative, client validation is UX-only | **CONFIRMED** (spot check — 14 of 15 `apps/web/src/modules/*` directories have a Zod `schema.ts`). |
| M5 | Insecure Communication | TLS, per A02 above | **CONFIRMED**, same platform-reliance caveat as A02. |
| M6 | Inadequate Privacy Controls | [privacy.md](privacy.md) — inventory, lawful basis, anonymise-on-erasure | **GAP, not fixed this pass.** `privacy.md §4`'s anonymise-on-erasure resolution is fully designed (null `name`/`phone`, keep the row/id for FK integrity) but **has zero implementation** — confirmed by grep for `anonymi[sz]e`/`erasure`/`gdpr` across both apps, zero hits; `customers/service.ts`'s `deactivateCustomer` only sets `deactivatedAt`, never touches `name`/`phone`. A real, bounded, but genuinely new endpoint to build (not a same-pass patch — it's request-handling, permissioning, and probably worth a beat of founder input given `privacy.md §2`'s own "provisional, pending legal review" framing around DPDPA applicability). |
| M7 | Insufficient Binary Protections | Assumed hostile by design — no business logic or secret ever lives client-side | **CONFIRMED.** `apps/mobile/lib/core/config/env.dart` only ever embeds the Supabase anon key and API base URL (both public-by-design); no service-role key or other secret found anywhere in `apps/mobile/lib`. |
| M8 | Security Misconfiguration | Same as A05 | **GAP, not fixed this pass.** `apps/mobile/android/app/build.gradle.kts` signs the **release** build with the debug keystore (`// TODO: Add your own signing config for the release build. // Signing with the debug keys for now`) — a real, concrete misconfiguration, but fixing it needs a real, founder-owned production keystore and its credentials, which this session cannot generate — the same category of founder-blocked action as MTS-01's printer hardware. No ProGuard/R8 minification configured either, informational rather than a hard finding. |
| M9 | Insecure Data Storage | [data-protection.md §3](data-protection.md#3-on-device-storage-encryption) — SQLCipher-encrypted local database | **GAP, not fixed this pass.** No SQLCipher package exists in `pubspec.yaml` at all; `core/database/database.dart`'s `driftDatabase(name: 'smart_pos_x')` is a plain, unencrypted SQLite file. Combined with M1, a lost/stolen/rooted device exposes both the session token and the full local sales/customer database in plaintext. Real mobile engineering work (SQLCipher's Drift integration, a migration path for already-installed unencrypted databases) — not a same-pass patch. |
| M10 | Insufficient Cryptography | Platform-standard TLS and platform Keystore/Keychain-backed key storage — no custom cryptographic implementation | **PARTIAL.** Confirmed: no homegrown crypto anywhere (grep for `encrypt`/`decrypt`/`AES`/`crypto\.` across both apps, zero hits) — that half of the claim holds. The other half ("Keystore/Keychain-backed key storage") is undermined by M1/M9 above; nothing is actually stored that way yet. |

## What this checklist confirms, and what it doesn't

**11 of 20 categories are genuinely CONFIRMED** against real code (A03, A04, A06, A08, A10, M2, M3,
M4, M5, M7, and the no-homegrown-crypto half of M10). **3 real gaps have now been fixed** (security
headers and the DR-025 audit-log coverage gap, Sprint 43; mutating/read/sync-push rate limiting,
Sprint 45). **7 real gaps remain, named and not silently deferred**:

1. **RLS's likely-inert defence-in-depth layer** — carries genuine production risk, needs founder
   input before any fix is attempted.
2. **Sign-in rate limiting** — architecturally unreachable from this codebase (found Sprint 45),
   needs a Supabase-side configuration check, not code.
3. **Mobile secure token storage** (M1) — real, bounded future engineering.
4. **On-device database encryption** (M9) — real, bounded future engineering.
5. **Customer-data anonymisation-on-erasure** (M6) — real, bounded future engineering.
6. **Alerting/monitoring infrastructure** (A09) — unbuilt, consistent with `incident-response.md`'s
   own already-stated Phase 18 deferral.
7. **Android release signing** (M8) — founder-owned action this session cannot perform (needs real
   production signing credentials).

This table is a snapshot of 2026-08-19 — it does not replace the actual verification work still to
come (a real penetration test before commercial launch, per the original v0.1.0 framing, which
still holds).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Full OWASP Top 10 and Mobile Top 10 traceability against this phase's and Phase 11's existing controls; no new gaps found. |
| 0.2.0 | 2026-08-19 | Sprint 43 (backlog.md M4 item 8) — every row re-verified against the real, running code, not the design docs cited as evidence. Found RLS is very likely inert for all real production traffic (no `FORCE ROW LEVEL SECURITY` anywhere, no code ever sets `request.jwt.claims` on the app's own connection) — flagged as the single most significant finding, deliberately not fixed pending founder confirmation of the real production database role, since a wrong fix risks a full outage. Found rate limiting is entirely unimplemented despite being claimed. Found and fixed a real DR-025 audit-log coverage gap (3 of 4 stock-movement types, plus settings changes, had no paired audit_log entry at all) across five repository functions, verified against a real database. Found and fixed missing `next.config.ts` security headers. Found four further real, named gaps not fixed this pass: mobile session storage falls back to plaintext `SharedPreferences` (M1), the local Drift database is unencrypted (M9), customer-erasure anonymisation is fully designed but has zero implementation (M6), and the Android release build signs with the debug keystore (M8, founder-blocked on real signing credentials). No alerting/monitoring infrastructure exists (A09), consistent with incident-response.md's own already-stated Phase 18 deferral. |
| 0.3.0 | 2026-08-19 | Sprint 45 — the rate-limiting gap from Sprint 43's finding #2 closed for the 3 classes actually reachable from this codebase (mutating/read/sync-push, a Postgres-backed fixed-window counter in `requirePermission`). Found while building it: the sign-in rate-limit class cannot be implemented in this codebase at all, since sign-in is a direct client call to Supabase Auth that never reaches an `apps/web` Route Handler — a real, previously-unnamed architectural gap, not just an unimplemented one. A07's row and the summary counts corrected accordingly. |
