# OWASP Checklist

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.12.0
> **Last updated:** 2026-08-21
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

   **A second, independent, and more fundamental possibility, found Sprint 59 and not yet ruled
   out: some of these policies may never have reached the real production database at all**, a
   different failure from "present but owner-exempt." `cd-workflows.md §1`'s own corrected account
   (Sprint 55) of the manual apply-by-hand step cited `implementation-log.md`'s "applied live"
   entries as evidence every file 001–019 eventually got applied — but that phrase, checked
   file-by-file against every sprint doc and implementation-log entry, appears explicitly only for
   `003`–`007`, `012`, and `015`. For `010`, `011`, `013`, `014`, `016` there is reasonable
   circumstantial evidence (each sprint's own demo explicitly ran "against production Supabase"
   with a passing cross-tenant RLS check for that table) but no file-specific confirming sentence.
   For **`017`/`018` (`sale_line_items`/`sale_payments`/`return_line_items` — Sprint 40's own
   "most significant security gap" fix, closing the exact tables that had *zero* RLS at all) and
   `019` (`devices`, Sprint 55)**, the documentary record contains **no confirmation at all** —
   Sprint 40's own text explicitly distinguishes verification "against the real applied SQL
   locally" from "the shared production Supabase project" and never claims the latter for these two
   files; Sprint 55's own demo script explicitly lists a real-Supabase smoke test as "not performed
   this sprint." "The application demonstrably works in production" is consistent with *either*
   explanation (owner-exempt-but-present, or absent-but-masked-by-the-app's-own-service-layer-scoping)
   — it cannot distinguish between them, so it cannot be used to rule this one out the way it was
   used to support the FORCE/role finding above. This session cannot check `pg_class.relrowsecurity`
   against the real production database directly — **the founder confirming, for at minimum `017`,
   `018`, and `019`, that these policies genuinely exist live is a precondition for the FORCE/role
   question even being the right next question to ask.**

   **A ready-to-run answer, added Sprint 62:**
   [supabase/sql/diagnostics/check_rls_status.sql](../../supabase/sql/diagnostics/check_rls_status.sql)
   — two read-only queries, paste directly into the Supabase Dashboard's SQL Editor for the
   production project. The first answers this finding's own question directly (every table's actual
   `rowsecurity`/`relforcerowsecurity` state, not what the migration files say should be true); the
   second answers the FORCE/role finding above in the same pass (every role's
   `rolbypassrls`/`rolsuper` flags, so the app's own `DATABASE_URL` role can be checked by name).
   Both questions, previously requiring the founder to work out how to check them, now have one
   five-minute paste-and-read action.
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
| A01 | Broken Access Control | [authorisation-model.md](authorisation-model.md)'s 7-step fail-closed evaluation order; [tenant-isolation.md](tenant-isolation.md)'s dual API+RLS enforcement | **PARTIAL, improved Sprint 55.** `requireSession`/`requirePermission` (`core/auth/session.ts`) genuinely fail closed — confirmed by reading the code, not assumed. RLS is enabled on all 20 real tables, but see finding #1 above: the "dual, independent" claim is unproven and likely false for the API's own connection today. Device-revocation (authorisation-model.md's step 2) is now built: `devices` table, `POST /auth/register-device`/`GET /devices`/`PATCH /devices/{id}/revoke`, `requireSession`'s per-request `devices.revoked_at` check via a new `X-Device-Id` header — verified against a real Postgres connection (98/98 integration checks, including the RLS deliberate-break-and-fix cycle). What remains PARTIAL is RLS's own unproven "dual, independent" claim (finding #1), unrelated to device revocation. |
| A02 | Cryptographic Failures | TLS everywhere ([data-protection.md §1](data-protection.md#1-in-transit)); on-device SQLCipher encryption ([data-protection.md §3](data-protection.md#3-on-device-storage-encryption)); no raw payment data ever held ([RR-007](../02-business-requirements/regulatory-requirements.md)) | **PARTIAL.** No card/PAN/payment-instrument fields exist anywhere in the schema — confirmed. TLS is a Vercel/Supabase platform default, nothing in this codebase weakens it. On-device encryption is a **GAP** — see M9 below, same finding, not restated twice. |
| A03 | Injection | Structural: Prisma parameterisation, banned raw-SQL pattern ([input-validation.md §3](input-validation.md#3-sql-injection-is-a-structural-non-issue-not-a-discipline-one)) | **CONFIRMED.** The only raw SQL in the whole codebase (`integration-tests/cross-tenant-isolation.test.ts`) interpolates only hardcoded internal identifiers from a fixed array, with real values passed as bound parameters — no production code path builds SQL from untrusted input. |
| A04 | Insecure Design | This entire 18-phase, design-before-code methodology — a threat model ([threat-model.md](threat-model.md)) produced before implementation, not retrofitted | **CONFIRMED** (process claim, verified against `git log`'s own chronology — the repository's first commit already references pre-existing phase docs it implements). |
| A05 | Security Misconfiguration | Platform defaults relied on deliberately; RLS enabled unconditionally with no bypass flag ([tenancy-model.md §3](../07-database/tenancy-model.md#3-rls-is-never-bypassed-including-by-the-apis-own-connection)) | **PARTIAL, one piece Fixed Sprint 43.** No committed secrets (`.env.example` only). No CORS config exists (mobile uses Bearer tokens, not cross-origin cookies — largely moot). `next.config.ts` had zero explicit security headers — **fixed this sprint** (`poweredByHeader: false`, `X-Content-Type-Options`/`X-Frame-Options`/`Referrer-Policy`). "RLS has no bypass flag" is technically true (no role has `BYPASSRLS` set) but, per finding #1, misses the table-owner exemption, which has the same practical effect — tracked there, not double-counted here. |
| A06 | Vulnerable and Outdated Components | Dependency currency is a Phase 14/18 operational concern | **CONFIRMED.** `.github/dependabot.yml` (Sprint 42) is real and complete — npm/pub/github-actions, weekly. |
| A07 | Identification and Authentication Failures | [identity-and-sessions.md](identity-and-sessions.md) — short access-token TTL, refresh rotation with reuse detection, rate-limited sign-in, no separate account-lockout DoS vector | **PARTIAL, mostly Fixed Sprint 45, narrowed further Sprint 64.** Mutating/read/sync-push rate limiting now built (finding #2 above) — see [rate-limiting.md](../11-api/rate-limiting.md). Sign-in's **server-side** limit remains a genuine architectural gap: unreachable from this codebase (sign-in never touches `apps/web`), needs Supabase's own platform-side configuration, still unconfirmed whether it's even active. **Client-side, built Sprint 64:** `SignInController` now throttles repeated failed attempts (exponential cooldown, resets on success) — real defense-in-depth, not a substitute for the server-side control. Token TTL/rotation/reuse-detection are real but entirely a Supabase Auth platform default this codebase neither implements nor separately tests — a legitimate architectural choice (identity-and-sessions.md §2 says so explicitly), just not something this repo's own code proves. |
| A08 | Software and Data Integrity Failures | Idempotency keys prevent duplicate/replayed mutations; CI-gated migrations | **CONFIRMED.** Idempotency verified in depth across Sprints 40/41/43 (including a real concurrency-race fix). `fast-integration`'s `prisma migrate deploy` step genuinely runs before any test. |
| A09 | Security Logging and Monitoring Failures | [audit-logging.md](audit-logging.md) — immutable, enumerated coverage of money/stock/permission actions; [incident-response.md §1](incident-response.md#1-detection)'s concrete alerting signals | **Two real gaps, both found this sprint; the audit-coverage one Fixed Sprint 43.** DR-025 ("every stock movement... produces exactly one corresponding audit-log entry") was unimplemented for 3 of 4 `stock_movements` types (`opening`/`sale`/`return` — only the summary `sale.completed`/`return.completed` entries existed, not one per movement row) and entirely unimplemented for the 4th (`adjustment`) and for settings changes — despite `audit-logging.md`'s own Phase 14 v0.1.1 correction already specifying the per-row requirement, and `implementation-log.md`'s Sprint 12 entry already naming stock-movement audit coverage as "a real, still-open gap" that was never subsequently closed. **Fixed this sprint** across `products/repository.ts`, `pos/repository.ts`, `returns/repository.ts` (both its auto-approval and manual-approval paths), `stock-movements/repository.ts`, and `settings/repository.ts` — verified for real against a real database (`integration-tests/audit-log-coverage.test.ts`). Alerting/monitoring infrastructure (Sentry or equivalent) is a **GAP, not fixed** — zero code or config exists anywhere; `incident-response.md` itself already says this is a future Phase 18 item, not a claim of present coverage. |
| A10 | Server-Side Request Forgery (SSRF) | No V1 feature accepts a server-fetched URL from client input | **CONFIRMED.** Zero `fetch(` calls anywhere in `apps/web/src` outside tests. |

## OWASP Mobile Top 10

| # | Category | This project's mitigation | Verified status |
| --- | --- | --- | --- |
| M1 | Improper Credential Usage | Tokens in platform secure storage only, never shared preferences/plain files | **Fixed, Sprint 47.** `flutter_secure_storage` was a `pubspec.yaml` dependency but was never imported or used anywhere in `apps/mobile/lib` — `Supabase.initialize()` now passes a `SecureLocalStorage` (`core/auth/secure_local_storage.dart`) as its `localStorage`, so the session/JWT is Keystore/Keychain-backed, not `SharedPreferences`-plaintext. No migration from the old plaintext value — a dated decision, since no real installed base exists yet to migrate. |
| M2 | Inadequate Supply Chain Security | Free/open-source package selections made deliberately | **CONFIRMED** (informational spot check — `pubspec.yaml`/`package.json` dependencies are all actively-maintained, mainstream packages). |
| M3 | Insecure Authentication/Authorisation | Same as A01/A07 — one model, not a separate mobile-specific one | **CONFIRMED**, same caveats as A01/A07 (mobile calls the identical Bearer-token endpoints as every other client; no separate/weaker path exists). |
| M4 | Insufficient Input/Output Validation | [input-validation.md](input-validation.md) — server-authoritative, client validation is UX-only | **CONFIRMED** (spot check — 14 of 15 `apps/web/src/modules/*` directories have a Zod `schema.ts`). |
| M5 | Insecure Communication | TLS, per A02 above | **CONFIRMED**, same platform-reliance caveat as A02. |
| M6 | Inadequate Privacy Controls | [privacy.md](privacy.md) — inventory, lawful basis, anonymise-on-erasure | **Fixed, Sprint 46.** `privacy.md §4`'s anonymise-on-erasure resolution, fully designed since Phase 12 but never implemented (confirmed by grep at the time — zero hits for `anonymi[sz]e`/`erasure`/`gdpr` across both apps), is now built: `POST /customers/{id}/erase` (Owner only), verified against a real database including FK-integrity survival. `privacy.md §2`'s "provisional, pending legal review" framing around DPDPA applicability still stands — this closes the *engineering* gap, not the separate legal-review item, which remains open and untouched. |
| M7 | Insufficient Binary Protections | Assumed hostile by design — no business logic or secret ever lives client-side | **CONFIRMED.** `apps/mobile/lib/core/config/env.dart` only ever embeds the Supabase anon key and API base URL (both public-by-design); no service-role key or other secret found anywhere in `apps/mobile/lib`. |
| M8 | Security Misconfiguration | Same as A05 | **Narrowed, Sprint 63 — the code side is fixed; a credential is still founder-owned.** `apps/mobile/android/app/build.gradle.kts` used to sign the **release** build with the debug keystore unconditionally; it now reads real signing credentials from a gitignored `key.properties` if one exists (standard Flutter pattern, `apps/mobile/android/key.properties.example` names the exact `keytool` command), falling back to the debug keystore, unchanged, when it doesn't. Nothing left to build — creating one real keystore and one `key.properties` file is the entire remaining step, the same category of founder-owned action as MTS-01's printer hardware, but no longer also a code task. No ProGuard/R8 minification configured either, informational rather than a hard finding. **Threaded into [release-checklist.md §2](../14-testing/release-checklist.md#2-pilot-ready-checklist) for the first time, Sprint 58** — this row had never been carried into the actual release gate before, an omission found and fixed the same sprint a second, related gap surfaced: the entire Android build→sign→upload CI pipeline `cd-workflows.md §2` describes was never actually built either. |
| M9 | Insecure Data Storage | [data-protection.md §3](data-protection.md#3-on-device-storage-encryption) — SQLCipher-encrypted local database | **Fixed, Sprint 48.** The local database now opens through a SQLCipher-enabled `sqlite3` build (`pubspec.yaml`'s `hooks.user_defines`, `package:sqlite3` 3.x's native-hooks mechanism — no separate `sqlcipher_flutter_libs` plugin, which is a no-op stub post-3.x), keyed via `PRAGMA key` with a 256-bit random value from `getOrCreateDatabaseEncryptionKey`, stored the same way M1's session token is (platform secure storage). Verified live against a real `android-arm64` debug build: `libsqlcipher.so` is genuinely bundled in the APK, and a dedicated test proves data written through a keyed connection is unreadable by a connection that never supplies the key. A pre-existing plaintext database file is detected and reset once on first launch after this update rather than migrated (`legacy_database_reset.dart` — the same "no migration path, pre-pilot" call already made for M1, applied here since it's the one case that risks real local data instead of a trivial re-sign-in). |
| M10 | Insufficient Cryptography | Platform-standard TLS and platform Keystore/Keychain-backed key storage — no custom cryptographic implementation | **CONFIRMED, Sprint 48.** Confirmed: no homegrown crypto anywhere (grep for `encrypt`/`decrypt`/`AES`/`crypto\.` across both apps, zero hits) — that half of the claim holds. Both halves of this row are now built: the session token (M1, Sprint 47) and the SQLCipher database key (M9, Sprint 48) are both genuinely Keystore/Keychain-backed. |

## What this checklist confirms, and what it doesn't

**12 of 20 categories are genuinely CONFIRMED** against real code (A03, A04, A06, A08, A10, M2, M3,
M4, M5, M7, M10, plus M9). **6 real gaps have now been fixed** (security headers and the DR-025
audit-log coverage gap, Sprint 43; mutating/read/sync-push rate limiting, Sprint 45;
customer-erasure anonymisation, Sprint 46; mobile secure token storage, Sprint 47; on-device
database encryption, Sprint 48). **4 real gaps remain, named and not silently deferred**:

1. **RLS's likely-inert defence-in-depth layer** — carries genuine production risk, needs founder
   input before any fix is attempted.
2. **Sign-in rate limiting, server-side** — architecturally unreachable from this codebase (found
   Sprint 45), needs a Supabase-side configuration check, not code. **Client-side defense-in-depth
   built Sprint 64** (`SignInController`'s exponential cooldown on repeated failed attempts) — a
   real, narrower mitigation the server-side gap doesn't make redundant.
3. **Alerting/monitoring infrastructure** (A09) — unbuilt, consistent with `incident-response.md`'s
   own already-stated Phase 18 deferral.
4. **Android release signing** (M8) — the code is fixed, Sprint 63; a real keystore is now the
   *entire* remaining gap, founder-owned (this session cannot generate real production signing
   credentials). **Threaded into `release-checklist.md §2` for the first time, Sprint 58** — it had
   sat in this list since Sprint 43 without ever reaching the actual release gate, alongside a
   second, related gap found the same sprint: the Android build→sign→upload CI pipeline
   `cd-workflows.md §2` describes was never actually built.

This table is a snapshot of 2026-08-19 — it does not replace the actual verification work still to
come (a real penetration test before commercial launch, per the original v0.1.0 framing, which
still holds).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Full OWASP Top 10 and Mobile Top 10 traceability against this phase's and Phase 11's existing controls; no new gaps found. |
| 0.2.0 | 2026-08-19 | Sprint 43 (backlog.md M4 item 8) — every row re-verified against the real, running code, not the design docs cited as evidence. Found RLS is very likely inert for all real production traffic (no `FORCE ROW LEVEL SECURITY` anywhere, no code ever sets `request.jwt.claims` on the app's own connection) — flagged as the single most significant finding, deliberately not fixed pending founder confirmation of the real production database role, since a wrong fix risks a full outage. Found rate limiting is entirely unimplemented despite being claimed. Found and fixed a real DR-025 audit-log coverage gap (3 of 4 stock-movement types, plus settings changes, had no paired audit_log entry at all) across five repository functions, verified against a real database. Found and fixed missing `next.config.ts` security headers. Found four further real, named gaps not fixed this pass: mobile session storage falls back to plaintext `SharedPreferences` (M1), the local Drift database is unencrypted (M9), customer-erasure anonymisation is fully designed but has zero implementation (M6), and the Android release build signs with the debug keystore (M8, founder-blocked on real signing credentials). No alerting/monitoring infrastructure exists (A09), consistent with incident-response.md's own already-stated Phase 18 deferral. |
| 0.3.0 | 2026-08-19 | Sprint 45 — the rate-limiting gap from Sprint 43's finding #2 closed for the 3 classes actually reachable from this codebase (mutating/read/sync-push, a Postgres-backed fixed-window counter in `requirePermission`). Found while building it: the sign-in rate-limit class cannot be implemented in this codebase at all, since sign-in is a direct client call to Supabase Auth that never reaches an `apps/web` Route Handler — a real, previously-unnamed architectural gap, not just an unimplemented one. A07's row and the summary counts corrected accordingly. |
| 0.4.0 | 2026-08-19 | Sprint 46 — M6's customer-erasure gap closed: `POST /customers/{id}/erase` (Owner only), verified against a real database including FK-integrity survival. M6's row and the summary counts corrected accordingly. |
| 0.5.0 | 2026-08-19 | Sprint 47 — M1's mobile secure-token-storage gap closed: `Supabase.initialize` now uses a `SecureLocalStorage` backed by `flutter_secure_storage`, replacing the plaintext `SharedPreferences` default. M10's row updated to reflect the session half is now genuinely Keystore/Keychain-backed (the SQLCipher-key half, M9, is not). M1's row and the summary counts corrected accordingly. |
| 0.6.0 | 2026-08-19 | Sprint 48 — M9's on-device database encryption gap closed: the local database now opens through a SQLCipher-enabled `sqlite3` build, keyed via `PRAGMA key` with a 256-bit random value from platform secure storage; verified against a real Android debug build (`libsqlcipher.so` genuinely bundled) and a dedicated test proving unkeyed reads fail. M10 now fully CONFIRMED (both halves built). M9's row and the summary counts corrected accordingly. |
| 0.7.0 | 2026-08-20 | Sprint 55 — A01's device-revocation half built: `devices` table, register/list/revoke endpoints, `requireSession`'s per-request check via a new `X-Device-Id` header. Verified against a real Postgres connection, including the RLS deliberate-break-and-fix cycle (98/98 integration checks). A01 remains PARTIAL overall — RLS's own "dual, independent" claim (finding #1) is a separate, still-open issue. |
| 0.8.0 | 2026-08-21 | Sprint 58 (documentation-accuracy only) — found the M8 Android-signing finding (open since Sprint 43) had never been threaded into `release-checklist.md`'s actual release gate, despite being named in this document's own "4 real gaps remain" list the whole time. Cross-referenced in M8's row and the summary's item 4. Also found and corrected in `cd-workflows.md`/`release-checklist.md` (not this document): the entire Android build→sign→upload CI pipeline was never actually built, a second, compounding gap. |
| 0.9.0 | 2026-08-21 | Sprint 59 (documentation-accuracy only, no code change — but a genuinely severe finding) — checked `cd-workflows.md §1`'s own blanket claim that "every numbered file 001–019 has, in practice, required a human to run it" (implying they eventually all were) against the actual documentary record, file by file. Found it imprecise in a materially dangerous direction: the confirming phrase "applied live" appears explicitly only for `003`–`007`, `012`, and `015`; for `017`/`018` (Sprint 40's own fix for the two tables with *zero* RLS at all) and `019` (`devices`, Sprint 55), there is **no confirmation anywhere on record** that these policies were ever actually applied to the real production Supabase database — Sprint 40's own text explicitly distinguishes local verification from "the shared production Supabase project" and never claims the latter for these two files. Added as a second, independent possibility to finding #1 above, since "the application demonstrably works in production" cannot distinguish "RLS present but owner-exempt" from "RLS never applied at all for these specific tables" — both look identical from the outside. This session cannot check the real production database directly; the founder confirming this for at minimum `017`, `018`, and `019` is now named as a precondition for the existing FORCE/role question, not a separate, lower-priority item. |
| 0.10.0 | 2026-08-21 | Sprint 62 (no code change to `apps/*`, but a new artifact): added `supabase/sql/diagnostics/check_rls_status.sql`, a read-only diagnostic answering both open questions in finding #1 directly against the real production database — every table's actual RLS state, and every role's RLS-bypass flags — rather than leaving the founder to work out how to check either. Referenced in finding #1 above and in `cd-workflows.md §1`. |
| 0.11.0 | 2026-08-21 | Sprint 63: M8 narrowed — `build.gradle.kts` now reads real signing credentials from a gitignored `key.properties` if present, falling back to the debug keystore unchanged when absent (standard Flutter pattern, exact `keytool` instructions in `key.properties.example`). The code gap is closed; a real keystore is now the entire remaining founder action, not a code task too. Summary item 4 corrected to match. |
| 0.12.0 | 2026-08-21 | Sprint 64: A07 narrowed — re-examined the sign-in rate-limiting finding the same way M8/RLS were re-examined, and found real client-side defense-in-depth work hiding inside the "architecturally unreachable" framing. `SignInController` now throttles repeated failed sign-in attempts with an exponential cooldown, resetting on success — the server-side gap is unchanged and still real, but no longer the *only* mitigation. A07's row and summary item 2 corrected to match. |
