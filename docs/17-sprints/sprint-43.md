# Sprint 43

> **Dates:** 2026-08-19 – 2026-08-19 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (backlog item 8 — OWASP checklist
> review against the real build)
> **Status:** Closed — M4 item 8 done. M4 now has item 9 remaining.

## Goal

Walk [owasp-checklist.md](../12-security/owasp-checklist.md)'s already-complete design-time
traceability table against the real, running M0–M4 codebase — not the design docs it cites as
evidence — confirming each of the 20 OWASP Top 10 / Mobile Top 10 mitigations is actually present in
code, per that document's own stated deferral ("It does not substitute for the actual verification
work... those are Phase 14/18 execution items this table points to, not replaces").

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| OWASP checklist review against the actual release build | Cross-cutting (Security) | 1 | 1–7 |

## Design decisions, found while writing the spec

This item turned out to be almost entirely about **what was found**, not what was built — 16 of the
20 rows required no code change (11 genuinely confirmed, 5 named as real gaps needing more than a
same-pass fix). Full per-row detail lives in
[owasp-checklist.md](../12-security/owasp-checklist.md) v0.2.0; the two findings below are the ones
that changed this sprint's own scope and risk posture.

1. **Row-level security is very likely inert for all real production API traffic — the single most
   significant finding of this project to date.** `apps/web/src/core/db/client.ts`'s Prisma
   connection never sets `request.jwt.claims`/`SET LOCAL ROLE`; no `FORCE ROW LEVEL SECURITY`
   exists anywhere in `supabase/sql/*.sql`; the role that runs `prisma migrate deploy` (the same
   `DATABASE_URL` the running app uses) becomes the owner of every table it creates, and Postgres
   exempts a table's own owner from its RLS policies regardless of `ENABLE`, independent of
   `BYPASSRLS`, unless `FORCE` is also set. `tenancy-model.md §3`'s claim that RLS is a genuine,
   independent second layer — the entire premise `tenant-isolation.md` and every cross-tenant test
   built since Sprint 40 has rested on — is therefore unproven for the app's own real connection,
   and the application's continued normal operation in production is only consistent with RLS being
   silently inert (owner-exempt) rather than actually enforced. **Deliberately not fixed this
   sprint.** Determining and applying the correct fix needs the real production `DATABASE_URL`
   role confirmed first — applying `FORCE ROW LEVEL SECURITY` blind risks every tenant-scoped query
   in production suddenly returning zero rows, a full outage, not a security improvement. This is
   the same category of "needs information only production access has" as the branch-protection
   setting Sprint 40 also could not apply itself — flagged for the founder, not worked around.
2. **Rate limiting is entirely unimplemented, despite `identity-and-sessions.md §6` and
   `rate-limiting.md` both describing it as built.** Grepping `apps/web/src` for
   `rate.?limit|throttle` returns zero hits; no rate-limiting package exists in `package.json`.
   Nothing in this application's own code slows a brute-force or credential-stuffing attempt against
   sign-in today. Real, standalone engineering scope (middleware, a rate-limit store, per-endpoint-
   class limits) — named, not fixed in this pass.
3. **A real, previously self-identified gap that stayed open for 15 sprints: DR-025's stock-movement
   audit-log requirement.** `audit-logging.md`'s own Phase 14 v0.1.1 correction already specified
   "every `stock_movements` row... gets exactly one paired `audit_log` entry" — and
   `implementation-log.md`'s Sprint 12 entry already named "stock_movements has zero audit coverage"
   as a real, open gap. Neither correction was ever actually implemented: `opening` (Sprint 04),
   `sale` (Sprint 05/27), `return` (Sprint 33/34), and `adjustment` (Sprint 22) movements all still
   had zero or only summary-level audit coverage as of this sprint. **Fixed in this pass** — a
   mechanical, low-risk, additive change (one more `auditLog.create`/`createMany` call inside each
   movement's own already-open transaction, reusing each movement's own id, the same 1:1 pattern
   already established for the movements themselves) across `products/repository.ts`,
   `pos/repository.ts`, `returns/repository.ts` (both its auto-approval and manual-approval paths —
   two separate code paths, found while implementing, both needed the same fix), and
   `stock-movements/repository.ts`. Settings changes (`audit-logging.md`'s "Money" category) had the
   same gap, fixed the same way in `settings/repository.ts`. Verified against a real database
   (`apps/web/integration-tests/audit-log-coverage.test.ts`), not by inspection.
4. **`next.config.ts` had zero explicit security headers.** Low-risk, additive, fixed in the same
   pass (`poweredByHeader: false`, `X-Content-Type-Options`/`X-Frame-Options`/`Referrer-Policy`) —
   no CSP added, since this API serves no HTML/inline scripts of its own to have a meaningful policy
   over, and a wrong CSP guess is worse than none.
5. **Four further real gaps found, all correctly out of this item's proportionate scope**: mobile
   session/JWT storage falls back to plaintext `SharedPreferences` (`flutter_secure_storage` is a
   dependency but is never actually used anywhere in `apps/mobile/lib`); the local Drift database has
   no SQLCipher encryption at all; `privacy.md §4`'s customer-erasure anonymisation is fully designed
   but has zero implementation; the Android release build signs with the debug keystore
   (`build.gradle.kts`'s own `// TODO` comment says so). None fixed this pass — each is real, bounded
   future engineering (the first three) or founder-blocked on real production credentials this
   session cannot generate (the last, the same category as MTS-01's printer hardware).

## Capacity check

1 person-day against estimate — landed on it for the review itself (walking all 20 rows plus the
4 same-pass fixes); the 6 named-but-deferred gaps are explicitly out of this item's own estimate,
consistent with how prior sprints have scoped found-but-larger gaps.

## Reserved capacity

- [x] Defect capacity reserved: the DR-025 audit-log-coverage gap (design decision #3) was a
      genuine, 15-sprint-old, previously self-identified bug, found and fixed in the same pass.
- [x] Documentation capacity reserved: `owasp-checklist.md` (full rewrite), `audit-logging.md`,
      `tenancy-model.md`, `identity-and-sessions.md`, backlog.md, this sprint doc,
      implementation-log, README bumps.

## Risks

- **Two real, flagged production risks, not silently accepted**: the RLS defence-in-depth question
  (design decision #1) and the absence of rate limiting (design decision #2) — both named clearly in
  `owasp-checklist.md`'s own "most important findings" section, not buried in a table row.
- **None new for production data from this sprint's own changes** — the audit-log fixes are purely
  additive inserts inside already-open transactions, verified against a real database before merge;
  the security-header change is a response-header addition with no behavioural effect on any
  existing client.

## Definition of Done

- [x] `docs/12-security/owasp-checklist.md` — every one of 20 rows re-verified against real code,
      verdicts and evidence recorded, not assumed from the docs it cites.
- [x] `products/repository.ts`, `pos/repository.ts`, `returns/repository.ts`,
      `stock-movements/repository.ts`, `settings/repository.ts` — the DR-025 audit-log-coverage fix,
      all four movement types plus settings changes.
- [x] `apps/web/integration-tests/audit-log-coverage.test.ts` — proves the fix for real against a
      real database (opening/sale/return/adjustment/settings, each asserting the exact expected
      audit-entry count).
- [x] `apps/web/src/modules/settings/service.test.ts` — updated for `updateSettings`'s new
      `authUserId` parameter and the `identityService` mock this required.
- [x] `apps/web/next.config.ts` — security headers added.
- [x] `tenancy-model.md`, `identity-and-sessions.md`, `audit-logging.md` — each corrected with a
      dated note pointing at the real finding, not just `owasp-checklist.md` alone.
- [x] Verified locally: full `test:integration` (86/86, 84 pre-existing + 2 new), full unit suite
      (209/209, unaffected), `tsc`/`eslint` clean, production build confirmed.
- [x] backlog.md, implementation-log, READMEs updated in the same PR.

## Demo script

**Local, run 2026-08-19**, mirroring `pr.yml`'s `fast-integration` job exactly:

1. Fresh `postgres:15` container, migrations + RLS applied. ✅
2. `pnpm --filter @smart-pos/web test:integration` → 86/86 passing (84 pre-existing + the new
   `audit-log-coverage.test.ts`'s 2 cases, proving one audit_log entry per stock_movements row across
   all four movement types, and one per settings change). ✅
3. `tsc --noEmit`/`eslint .`/`pnpm test` (209/209, unaffected) all clean. ✅
4. Production build, CI-style placeholder env vars — succeeded, including the new `headers()`
   config. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the fourth
consecutive sprint (Sprint 40, 41, 42, 43) to find a real gap between what this documentation set
claims and what the code actually does, and the first to find one — the RLS defence-in-depth
question — with genuine, unmitigated production risk attached, not just a stale count or an unbuilt
test suite. The pattern holds: a claim is only as reliable as the last time someone actually built
against it, and this was the first time anyone tried to verify the RLS/rate-limiting claims
specifically since they were written in Phase 12.

M4 — Reports, Settings, and Release Readiness now has item 9 remaining, per
[backlog.md §5](backlog.md#5-m4--fully-decomposed-2026-08-16-now-that-m3-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-19 | Sprint 43 planned and built same-day: all 20 OWASP checklist rows re-verified against real code; the RLS defence-in-depth gap and the complete absence of rate limiting flagged as real, unmitigated production risk (not fixed, pending founder input); a 15-sprint-old, previously self-identified DR-025 audit-log-coverage gap closed for real across 5 repository functions; security headers added; four further real gaps named for future scope. M4 item 8 done, item 9 remains. |
