# Implementation Log

> **Status:** 🟡 In progress
> **Phase:** 18 — Implementation
> **Version:** 0.26.0
> **Last updated:** 2026-08-14
> **Owner:** CTO / All engineering roles

Module-by-module record: dates, decisions, deviations, lessons — per this phase's own charter.
Entries below cover pre-module scaffolding (Sprint 01); once the first module (the Phase 16 walking
skeleton) begins in earnest, it gets its own dated entry following the same format.

---

## 2026-07-31 — Sprint 01: repository scaffold, Supabase Auth wiring

**What landed:**
- Monorepo initialised: `pnpm` workspace (`apps/web`, `packages/contracts`), per
  [monorepo-layout.md](../08-folder-structure/monorepo-layout.md). `apps/mobile` is **not**
  scaffolded — see below.
- `apps/web`: a working Next.js (App Router) scaffold. Verified locally (not just written):
  `pnpm lint`, `pnpm typecheck`, `pnpm test` (2 passing unit tests), and `pnpm build` all pass
  clean on a fresh `pnpm install`.
- A minimal Prisma schema (`tenants`, `users` only — the two tables Sprint 01 actually needs, not
  the full 22-table schema) and the Custom Access Token Hook SQL function
  (`supabase/sql/001_custom_access_token_hook.sql`), per
  [authentication.md §1](../11-api/authentication.md#1-why-supabase-auth-issues-the-token-not-a-second-one-from-our-api).
- Session resolution (`src/core/auth/session.ts`) implementing steps 1 and 3 of
  [authorisation-model.md §2](../12-security/authorisation-model.md#2-evaluation-order--every-request-in-this-sequence-fail-closed-at-every-step)'s
  evaluation order — JWT verification and `tenant_id` claim extraction. Steps 2 (device
  revocation) and 4 (role resolution) are deliberately not implemented yet; those tables don't
  exist until a later sprint.
- `.github/workflows/pr.yml`: `lint-typecheck`, `unit-tests`, `build` jobs — the real subset of
  [ci-workflows.md](../15-github-project/ci-workflows.md)'s eventual full pipeline that Sprint 01's
  actual code can support. `import-boundaries`, `fast-integration`, and `bundle-secret-scan` are
  added as the sprints that give them something real to check land.

**Deviation from the specification, and why (per this phase's own rule — recorded here, not
silently absorbed):**
- `tenants.created_by` references `users.id`, and `users.tenant_id` references `tenants.id` — a
  circular dependency neither Phase 07's [schema-server.md](../07-database/schema-server.md) nor
  any later phase caught, because a brand-new tenant and its first user are created in the same
  transaction, before either row exists for the other to reference. Prisma's schema DSL can express
  the relation but not the fix; the actual fix (`DEFERRABLE INITIALLY DEFERRED` foreign keys,
  checked at `COMMIT` rather than per-statement) is a hand-edited follow-up migration once a real
  database exists, noted directly in `prisma/schema.prisma`'s comments. **This is exactly the kind
  of implementation-time finding this phase's rules expect to be surfaced and fixed, not the
  specification being wrong** — Phase 07 could not have discovered this without actually attempting
  the insert order a real signup requires.
- Removed a guessed `"packageManager": "pnpm@10.9.8"` pin from the root `package.json` — the exact
  version string was invented before checking what was actually installed (`9.15.0`), and Corepack
  failed trying to fetch a version that doesn't exist on the registry. Fixed by not pinning at all
  and relying on the `engines.pnpm` range instead; a lesson for any future version-pinning decision
  in this repo: verify the installed version first, never state one from assumption.

**What's blocked on the founder, not on more design work:**
- **Flutter SDK is not installed** on the machine this was scaffolded on — `apps/mobile` has no
  Dart code, only [apps/mobile/README.md](../../apps/mobile/README.md) explaining exactly what to
  run once the SDK is available. Nothing in [mobile-structure.md](../08-folder-structure/mobile-structure.md)
  is blocked by this; scaffolding it is mechanical once the SDK exists.
- **No real Supabase project exists yet.** The Custom Access Token Hook SQL is written and ready to
  apply, but actually creating a Supabase project, running the SQL, and wiring the Auth Hook in its
  Dashboard is a founder action — the same category of gap as
  [device-matrix.md §3](../14-testing/device-matrix.md#3-this-is-a-founder-action-not-an-engineering-one--stated-plainly)'s
  physical reference device and [OD-06](../01-vision/open-decisions.md)'s capacity answer. Sprint
  01's demo script (sign up a real user, inspect the JWT, attempt a cross-tenant read) cannot be
  run end-to-end until this exists.
- ~~No GitHub remote exists yet~~ — **resolved 2026-07-31.** Founder created
  [github.com/rintu007/smart-mobile-pos](https://github.com/rintu007/smart-mobile-pos); both local
  commits pushed to `main`. **Still outstanding, and still a founder action:** branch protection and
  required status checks ([repository-setup.md §2](../15-github-project/repository-setup.md#2-branch-protection-on-main))
  are GitHub repository *settings*, not something pushable via `git` — `gh` CLI is not installed in
  this environment either, so this is configured once directly in the repository's Settings →
  Branches page (or by installing and authenticating `gh` first). The PR-preview deployment
  ([cd-workflows.md](../15-github-project/cd-workflows.md)) similarly needs the repo connected to a
  Vercel project, not yet done.

## 2026-08-01 — Sprint 01: live Supabase project, schema migration, Auth Hook function

**What landed:**
- Real Supabase project provisioned (`sitspwhzbzjeylhafjsz`, `ap-south-1`). `apps/web/.env.local`
  populated with real credentials — never committed (gitignored), never echoed into docs.
- **Direct connection (`db.<ref>.supabase.co:5432`) confirmed unreachable from this network** — a
  `P1001` on `prisma db execute` combined with Supabase's well-documented IPv6-only-by-default
  direct connection. Fixed by using the pooler (Supavisor) instead: `DIRECT_URL` is the Session-mode
  pooler connection (port 5432 on the pooler host — supports prepared statements, used for
  migrations); `DATABASE_URL` is the Transaction-mode pooler connection (port 6543, `?pgbouncer=true`,
  used for runtime queries).
- **A red herring worth recording:** `pnpm exec prisma db execute --url <transaction-mode-url>`
  hung indefinitely (tested twice, 45s and 120s timeouts, both moved to background and killed).
  Raw TCP checks (`Test-NetConnection`, all three of the pooler hostname's A records) all succeeded
  on port 6543, ruling out a network/firewall block. The actual runtime path — a real
  `PrismaClient` issuing `$queryRaw` — connected via the identical transaction-mode URL in under a
  second. Conclusion: `prisma db execute`'s CLI path has a known incompatibility with transaction-mode
  PgBouncer connections (it isn't the connection that's broken); `db execute` and `migrate
  deploy`/`dev` should only ever be pointed at `DIRECT_URL` (session mode), matching the schema's own
  `directUrl` split. `DATABASE_URL` (transaction mode) is confirmed working for its actual intended
  use — the app's runtime Prisma Client — and needs no further verification.
- Schema applied as a real migration: `prisma migrate dev --create-only` generated
  `prisma/migrations/20260801050159_init/`, then hand-edited per the circular-FK finding already
  logged below — added `tenants_created_by_fkey` (absent from the Prisma-generated SQL entirely,
  since `Tenant.createdBy` has no relation in `schema.prisma` by design) and changed
  `users_tenant_id_fkey` to add `DEFERRABLE INITIALLY DEFERRED` to both. Applied with
  `prisma migrate deploy` (no shadow-database diffing against hand-edited SQL). Verified live via
  `pg_constraint`: both constraints report `condeferrable = true, condeferred = true`.
- `supabase/sql/001_custom_access_token_hook.sql` applied against the live database via
  `prisma db execute --file`. Verified live: `custom_access_token_hook` and `current_tenant_id`
  both appear in `information_schema.routines`.

**What's blocked on the founder, not on more design work:**
- Branch protection and Vercel connection remain outstanding, as previously logged.

## 2026-08-01 — Sprint 01: Dashboard hook wired, demo script run, two real findings fixed

Founder wired the Custom Access Token Hook in Dashboard → Authentication → Hooks. This unblocked
running the actual Sprint 01 demo script end-to-end (docs/17-sprints/sprint-01.md's Demo script
steps 3–4) — done via a throwaway Node script using `@supabase/supabase-js` (admin client to create
two test tenants/users as fixtures, anon client to sign in and query as a real end user would; not
committed, since it isn't part of the app — Sprint 02's actual signup endpoint is backlog item 3).
Two real, previously-untested assumptions broke on first contact with the live database, both now
fixed and re-verified live:

1. **The hook function needs `security definer`.** First sign-in attempt returned `HTTP 500
   unexpected_failure — Error running hook`. Cause: the function was `language plpgsql stable`
   with no security clause, so it ran as its invoker (`supabase_auth_admin`), which has no grant to
   read `public.users`. Fixed by adding `security definer set search_path = ''` — the same pattern
   Supabase's own Custom Access Token Hook documentation recommends, which this project's SQL had
   omitted. Re-applied and confirmed: sign-in now returns 200 with a JWT whose `tenant_id` claim
   correctly matches the signed-in user's tenant.
2. **`ON DELETE RESTRICT` cannot actually be deferred, even when marked `DEFERRABLE INITIALLY
   DEFERRED`.** Found while writing the demo script's own cleanup step: deleting the two fixture
   tenants/users (in either order, even inside one transaction) failed immediately instead of
   deferring to commit. Postgres only allows a deferred check on `NO ACTION`, never on `RESTRICT` —
   a real gap in the original migration's circular-FK fix, not a Prisma or tooling issue. Fixed with
   a follow-up migration (`20260801051705_fix_deferred_fk_delete_action`) changing both
   `tenants_created_by_fkey` and `users_tenant_id_fkey` to `ON DELETE NO ACTION ... DEFERRABLE
   INITIALLY DEFERRED`; `prisma/schema.prisma`'s `User.tenant` relation updated to
   `onDelete: NoAction` to match. Re-verified: a transactional two-row hard-delete (tenant + its
   creating user, either order) now succeeds.

Also added RLS to `tenants` and `users` (`supabase/sql/002_rls_tenants_users.sql`), per
[tenancy-model.md §2](../07-database/tenancy-model.md#2-the-rls-policy-template) — `tenants` uses
`id = current_tenant_id()` rather than the standard `tenant_id = current_tenant_id()` template,
since `tenants.id` *is* the tenant identifier. This is what made the demo's cross-tenant-denial step
meaningful rather than vacuous.

**Demo script result, evidenced (not just "should work"):** signed in as tenant A's test user;
decoded JWT's `tenant_id` claim matched tenant A's ID exactly; tenant A reading its own `tenants`
row via the anon-key/RLS-subject client succeeded; tenant A attempting to read tenant B's `tenants`
row by ID returned an empty result (denied, not a 500 or a leak) — the first real, live instance of
[tenant-isolation.md](../12-security/tenant-isolation.md)'s guarantee. This is a manual, one-off
proof for Sprint 01's narrow two-table scope, not the full automated cross-tenant CI suite
([tenancy-model.md §5](../07-database/tenancy-model.md#5-the-proof-automated-cross-tenant-negative-test-suite))
— formalizing that suite in CI is real work (a live test project wired into CI secrets) tracked to
Phase 14/18 as already noted, not built now just because this proof exists.

**What's blocked on the founder, not on more design work:** nothing — Sprint 01 is fully closed.

## 2026-08-01 — Sprint 01: branch protection, first real CI run, Sprint 01 closed

Founder chose to have `gh` CLI installed and authenticated in this environment (device-code login,
confirmed by the founder in-browser) rather than doing the remaining GitHub configuration manually.
This unblocked finishing Sprint 01's Repository/CI item end-to-end:

- **Repo visibility**: `repository-setup.md §1` specifies private; the repo was actually public.
  Asked the founder directly rather than silently changing it — chose to make it private. Then hit
  a real constraint: **GitHub's free tier does not support branch protection on private
  repositories at all** (a straight 403, "Upgrade to GitHub Pro or make this repository public").
  Asked again rather than guessing a workaround; founder chose to revert to public so branch
  protection works on the free tier. (Vercel deployment already existed and was already public
  regardless via its own preview links, so this doesn't change the actual exposure much — noted for
  completeness, not as a justification made unilaterally.)
- **Branch protection applied** to `main`: required status checks (`lint-typecheck`, `unit-tests`,
  `build` — the three jobs that actually exist in `pr.yml` today, not the full future set from
  `ci-pipeline.md`, matching this project's own incremental-CI practice), `enforce_admins: true`,
  `required_conversation_resolution: true`, force-push and branch deletion disabled.
  `required_approving_review_count: 0` — per `repository-setup.md §3`'s own named solo-founder gap,
  not a silent weakening: a literal "1 required approval" setting would permanently block a solo
  founder from merging anything, since GitHub does not allow self-approval and there is no second
  reviewer. The self-review-against-the-PR-template compensating control is what actually governs
  merge quality until a second engineer exists.
- **First real PR** ([#1](https://github.com/rintu007/smart-mobile-pos/pull/1)) opened to actually
  exercise `pr.yml` for the first time (zero GitHub Actions runs had ever happened on this repo
  before this). A direct push to `main` was attempted first as a control — **blocked by Claude
  Code's own auto-mode safety classifier before it ever reached GitHub**, so the proof of "direct
  pushes are blocked" came from the proper branch+PR workflow instead, not from actually testing
  GitHub's rejection directly.
- **CI failed twice on its first real run**, on things that never surfaced locally — the exact
  pattern now recorded as Sprint 01's retrospective finding
  ([retrospective-log.md](../17-sprints/retrospective-log.md)):
  1. `pnpm/action-setup` had no pnpm version to install — the `packageManager` field was removed
     entirely back when the guessed `pnpm@10.9.8` broke Corepack locally, and never replaced with
     the real, verified version. Fixed: `"packageManager": "pnpm@9.15.0"` (the actual installed
     version, confirmed via `pnpm --version` before pinning — the same discipline the original
     mistake violated).
  2. `@typescript-eslint/triple-slash-reference` flagged `next-env.d.ts`'s own
     `path="./.next/types/routes.d.ts"` line — Next.js's typed-routes feature appends this to its
     own autogenerated file (whose own header says "should not be edited"), and it should equally
     not be linted. Fixed by adding it to `eslint.config.mjs`'s `ignores`.
- All three jobs passed after both fixes; PR #1 merged (squash) into `main`.

**Sprint 01 is now fully closed** — both backlog items (Repository/CI, Identity/Auth) done and
demoed against real infrastructure, not just described as ready. Sprint 02 (the first real module,
per [backlog.md](../17-sprints/backlog.md) item 3 — the `tenants`/`stores` signup write path) is
planned next, following this same phase's standing rule against batch-authoring future sprints ahead
of time.

## 2026-08-01 — Sprint 02 planning: closing a real specification gap before writing code

Before starting Sprint 02's actual implementation, planning surfaced that
[docs/README.md](../README.md)'s non-negotiable rule #1 ("no implementation begins before its
module specification is approved") had already been violated by Sprint 01 — real Authentication-
module code (hook, `users` schema, RLS) was live against a real database with no
`modules/authentication/specification.md` ever having existed. Rather than let Sprint 02 repeat
that gap for Company & Store Setup, both specifications were authored now:
[authentication/specification.md](../modules/authentication/specification.md) (retroactive — catches
the document up to what Sprint 01 actually built, honestly marking device
registration/revocation as specified but not implemented) and
[company-store-setup/specification.md](../modules/company-store-setup/specification.md)
(prospective — drives Sprint 02 itself). Also found and fixed: Phase 11 never specified how the
very first `tenants`/`stores`/`users` rows get created — `authentication.md`'s issuance flow starts
from "already signed in," and the only existing endpoint (`POST /users/invite`) is for inviting
*additional* users to an *existing* tenant. Added a full `POST /api/v1/onboarding` contract to
[identity.md](../11-api/endpoints/identity.md), including the non-obvious behaviour that the access
token from the initial Supabase `signUp` call does **not** carry `tenant_id` until the client
explicitly refreshes its session after onboarding completes (the hook only runs at mint/refresh,
and minting happened before these rows existed).

Also found and fixed a real ambiguity in [modules/README.md](../modules/README.md)'s own Rule 2
("only one module 🔨 at a time"): Phase 18's README already calls the entire M0 walking skeleton
"the first module... it touches every architectural layer," which by design spans multiple Registry
rows (Authentication, Company & Store Setup, Products, POS, Sync) simultaneously — a real
inconsistency between two already-approved documents, not a new decision. Resolved by amending
Rule 2 with a named, dated exception: during M0, "one module" means M0 itself; the exception ends
once M0 closes.

## 2026-08-01 — Sprint 02: `POST /api/v1/onboarding` built and demoed live

**What landed:** `src/modules/identity/{schema,repository,service}.ts` and
`app/api/v1/onboarding/route.ts`, per [company-store-setup/specification.md](../modules/company-store-setup/specification.md) —
the layering `Route Handler → service → repository → Prisma` per
[backend-structure.md §2](../08-folder-structure/backend-structure.md#2-the-layering-rule-concretely).
RLS enabled on `stores` (`supabase/sql/003_rls_stores.sql`), applied live. A new
`requireAuthenticatedUser` in `src/core/auth/session.ts` — deliberately does not require a
`tenant_id` claim, since onboarding's entire purpose is to be callable by an identity that doesn't
have one yet; `requireSession` (which does require it) would incorrectly reject exactly the
callers this endpoint needs to serve. 6 unit tests for the service layer (`vi.mock`-ed repository),
covering the create path, same-IDs idempotent retry, rejected second attempt, and the concurrent
double-submission race (`P2002` on `auth_user_id` translated to `ALREADY_ONBOARDED`).

**A real bug, found only by running against the live database, not by inspection:** the repository
originally inserted `tenant`, `store`, `user` in that order — correct for the tenant↔user
*deferred* circular pair, but `stores.created_by → users.id` is an ordinary, non-deferred foreign
key. Inserting `store` before `user` existed failed immediately with `stores_created_by_fkey`,
twice (once in the actual repository code, once again in the demo script's own separate fixture for
a second tenant, which had the identical bug independently). Fixed by reordering to
tenant → user → store — the general lesson, now worth carrying forward: **only the specific pair a
deferred constraint was written for is actually deferred; every other FK into the same set of
tables still enforces normal insert-order requirements**, and that has to be reasoned about
per-constraint, not assumed to follow from "this table participates in a deferred relationship
somewhere."

**Demo script run 2026-08-01, all 6 steps passed** against the real database and a real Supabase
Auth identity: onboarding creates exactly one tenant/store/user; the post-onboarding session
refresh carries the correct `tenant_id` claim; a same-IDs replay is a true no-op; a second distinct
attempt from the same identity is rejected with `ALREADY_ONBOARDED`; a cross-tenant `stores` read
is denied by the new RLS policy. Verified via a direct call into the same transaction the Route
Handler uses (the HTTP-layer wrapper itself — Zod parsing, auth, response shaping — is thin and
already typechecked/linted/build-verified), the same "prove the part that can actually break, not
the part the type system already guarantees" approach Sprint 01 used.

**Two more real gaps found by this PR's own CI run, not by inspection:**
- `lint-typecheck` and `unit-tests` never ran `prisma generate` — only the `build` job had that
  step, added at Sprint 01 time for a reason no committed code had actually exercised until this
  PR's code was the first to use real Prisma model/namespace types. `Cannot find module
  '.prisma/client/default'` and `Property 'PrismaClientKnownRequestError' does not exist` were the
  two symptoms. Fixed by adding the same `prisma generate` step to both jobs in `.github/workflows/pr.yml`.
- Pushing that fix itself failed once, separately: `refusing to allow an OAuth App to create or
  update workflow .github/workflows/pr.yml without workflow scope`. The `gh` CLI's token from
  Sprint 01 was authorized with `repo`/`read:org`/`gist` only — editing workflow files needs the
  `workflow` scope specifically, which GitHub does not imply from `repo`. Fixed via
  `gh auth refresh -s workflow` (a second founder device-code confirmation).
- **Not yet resolved, flagged rather than silently left broken:** the PR's Vercel preview deployment
  failed (separately from GitHub Actions CI) on every push. Vercel is not a required status check
  ([repository-setup.md §2](../15-github-project/repository-setup.md#2-branch-protection-on-main)
  only names the three GitHub Actions jobs), so this didn't block merging, but it's a real,
  unexplained gap — diagnosing it needs `vercel inspect` against a real Vercel login, which this
  environment doesn't have. Founder action, tracked alongside the pre-existing Vercel-connection
  item rather than a new separate one.

**What's blocked on the founder, not on more design work:** nothing — resolved below.

## 2026-08-01 — Vercel fixed and verified live; two real bugs found only by real HTTP requests

Founder asked to see the deployment live, and provided a Vercel token (`vercel.com/account/tokens`,
used locally only, never committed) to unblock diagnosing the failure already flagged above.

**Root cause of the Vercel failure, same as the earlier CI one but in a third place**: Vercel's
build command is plain `pnpm run build`, which never had the explicit `prisma generate` step CI's
`build` job has separately. Fixed at the actual root this time — `prisma generate && next build` is
now the `build` script itself in `apps/web/package.json`, so *any* environment that runs `pnpm
build` (Vercel, CI, or a fresh clone) gets a real client first, not just the ones with their own
separately-remembered CI step.

**Deploying it live surfaced something this project had not actually done yet: send a real HTTP
request to this endpoint.** Every verification so far — Sprint 02's "demo," the unit tests, `tsc
--noEmit`, `next build` — either called the service layer directly or only compiled the route
handler, never executed it against a real request. The first real `curl` against it (still
pre-fix, testing the earlier Vercel deploy) returned `500`, not the `401` the code should produce
for an unauthenticated call. Two real, distinct bugs, both invisible to everything run before now:

1. **`NextResponse.next()` throws at runtime inside an App Router Route Handler** — it's
   middleware-only. The onboarding route used it as a placeholder response object to let
   `@supabase/ssr` write cookies onto before the real response was known. Fixed by using `new
   NextResponse()` instead, which supports the same `.cookies` API without that restriction.
2. **The cookie-based `@supabase/ssr` client never reads an incoming `Authorization` header at
   all.** This is a much bigger finding than the crash: the mobile API (`app/api/v1/*`) is
   documented and intended to be called with `Authorization: Bearer <token>`
   ([authentication.md](../11-api/authentication.md)), never cookies — a mobile app has no browser
   cookie jar. `@supabase/ssr`'s `createServerClient` is built for cookie-based browser sessions;
   passed a bearer token in a header, it simply doesn't see it and reports no session. **Every
   route using the old `requireSession`/`requireAuthenticatedUser` would have rejected every real
   mobile-client request**, not just onboarding's — this was never exercised because nothing had
   sent a real request with a real token before. Fixed by rewriting `src/core/auth/session.ts` to
   extract the bearer token directly and verify it via a plain (non-SSR) client's
   `auth.getUser(token)`, which doesn't depend on cookies at all.
   `src/lib/supabase/server.ts` (the cookie-based client) is kept, not deleted — it's the
   documented plan for the future web admin's own Server Actions
   ([backend-structure.md](../08-folder-structure/backend-structure.md)), a genuinely
   cookie/browser-session context where it's the right tool. It's just not wired to anything yet.

**Verified end-to-end against both a local dev server and the live Vercel production URL**, not
just re-typechecked: unauthenticated request → `401`; real bearer token → `201` with the three
correct rows created; malformed body → `422`. Live URL:
`https://smart-mobile-pos-web.vercel.app` (health check and onboarding both confirmed working).
Vercel's Production and Preview environments now also have the same 5 Supabase/database
environment variables as `.env.local`.

**The honest lesson, worth being blunt about**: "the service layer is unit-tested and the build
compiles" was treated as sufficient confidence to call Sprint 02 demoed and done. It wasn't — an
HTTP-layer bug and an authentication-mechanism bug both sat completely invisible through unit
tests, typecheck, lint, and three separate CI runs, because none of them, and no demo run so far,
had ever actually sent a request to the route handler. This is the same shape of gap Sprint 01's
retrospective already named once ("verified locally" ≠ "CI-ready") recurring one layer deeper
("service-layer tested" ≠ "HTTP endpoint works") — worth its own retrospective note, not just a log
entry, since the concrete fix (send at least one real HTTP request before calling an endpoint
demoed) generalizes to every future endpoint, not just this one.

## 2026-08-01 — Sprint 03: Flutter SDK installed, `apps/mobile` scaffolded, local Drift database built

The founder authorised installing the Flutter SDK directly (rather than doing it themselves or
finding non-blocked work instead), since every remaining M0 backlog item — 5 through 11 — depends
on `apps/mobile` existing, which had been a named, un-actioned gap since Sprint 01.

**Flutter SDK install:** C: had only ~7 GB free, so the SDK was cloned via `git clone
https://github.com/flutter/flutter.git -b stable` into `D:\flutter` instead — outside this repo,
not committed. Added to the user `PATH` permanently. `flutter doctor` confirmed Flutter itself is
healthy (3.44.8, stable) but the Android SDK is not installed — a real, separate, much larger
install (Android Studio or standalone SDK components) not needed for this sprint's actual scope
(pure Dart schema/query code, verified via `flutter test`, needs no device or emulator) and
deliberately deferred to whichever sprint first needs to build/run on Android.

**Scaffold:** `flutter create --org com.smartposx --project-name mobile --platforms=android .` in
`apps/mobile`, then reshaped into `mobile-structure.md`'s feature-first layout (`app/` composition
root, `core/database/` for this sprint's actual content, `features/` left empty — no feature has
real content yet).

**Two real package-version findings**, both discovered by actually running `flutter pub add` and
reading pub.dev, not by any prior assumption in this project's docs:

1. `riverpod_lint`/`custom_lint`/`riverpod_generator` don't yet support Riverpod 3.4.2 cleanly — a
   genuine dependency-solver conflict with `drift_dev` (`riverpod_generator` requires an `analyzer`
   version range incompatible with what `drift_dev`/`flutter_test` pin). Resolved by dropping all
   three; Riverpod itself works fine with manual (non-code-generated) provider syntax, used until
   the ecosystem catches up.
2. `sqlite3_flutter_libs` — the package most existing Flutter/Drift material assumes is needed —
   resolved to `0.6.0+eol`. Checked pub.dev directly: it's explicitly marked obsolete, superseded by
   `sqlite3` v3.x's own native-library bundling, with `drift_flutter` as the current recommended
   Flutter setup package. Used `drift_flutter` instead of hand-wiring `sqlite3_flutter_libs`.

**Schema built:** `outbound_queue` (full V1 shape, no ambiguity — schema-local.md already fully
specifies it) plus a deliberately minimal `products`/`sales`/`sale_line_items`/`sale_payments`/
`stock_movements` slice sized to M0's actual exit criterion (cash-only, no tax/discount/variants/
trading-day/device attribution — all M1/M2 scope or dependent on local tables that don't exist yet).
Each table file's header comment states exactly what's deferred and why, so the next sprint touching
these tables sees the boundary next to the code, not just in this log entry — the same fix Sprint
02's retrospective asked for after the deferred-FK boundary blurred in memory a few days later.

Two Drift-specific implementation findings, fixed immediately via `flutter analyze`:
`int64()` columns map to Dart `BigInt` in this Drift version, not `int` — switched every money
column to plain `integer()` instead, since this app has no web target (the JS-precision concern
`int64()` exists for) and `BigInt` arithmetic would be far less ergonomic throughout till/catalogue
code than plain `int`. And a `.check(method.isIn([...]))` column constraint referencing its own
getter triggered an analyzer `recursive_getters` warning — switched to `.customConstraint(...)` with
the raw SQL, which is unambiguous.

**Verified for real, not just compiled:** `flutter test` — schema opens with no error, an
`outbound_queue` row round-trips, and a full sale (line item + cash payment + stock movement) writes
and reads back correctly across all five tables, plus a widget test confirming the home screen
renders after actually querying the live (in-memory) database through the same Riverpod provider
`main.dart` wires up in production. This is the mobile-side application of the "prove it for real,
not just that it typechecks/compiles" rule Sprint 02's addendum established for HTTP endpoints.

`pr.yml` gained a `mobile-analyze-test` job (`flutter analyze` + `flutter test` on every PR touching
`apps/mobile`) — not yet proven green on an actual PR run, per Sprint 01's own rule against
inferring CI success from local success.

## 2026-08-01 — Sprint 04: `POST /api/v1/products` built and demoed live; a real `requireSession` bug found and fixed

Planning found a real spec gap before any code was written: `catalogue.md`'s already-approved
`POST /products` contract requires `category_id`/`unit_id`, but `backlog.md`'s M1 row lists
Categories and Units as M1 scope — and `FR-032`/`FR-035` (Phase 03, approved) also require
category/unit at creation. M0's actual first cut can't meet any of that yet. Resolved the same way
Sprint 02 resolved its own spec gaps: a dated correction note in `catalogue.md`, a new
`docs/modules/products/specification.md` scoped honestly to name/price only, and the module
registry's Products row naming the gap against both its listed dependency and the FRs explicitly,
rather than quietly building past it.

**Built:** `Product` Prisma model (M0-minimal columns only — `id`, `tenant_id`, `name`,
`price_minor_units`, `created_at`, `updated_at`, `created_by`), migration
`20260801142244_add_products_m0_minimal` applied live, RLS (`supabase/sql/004_rls_products.sql`)
applied live. Money stored as Prisma `BigInt` (matching `schema-server.md`'s `BIGINT` exactly,
unlike the mobile Drift schema's deliberate `int64→int` simplification in Sprint 03 — no
web-JS-precision reason to deviate server-side), converted to a plain `Number` only at the JSON
response boundary. Added `identityService.resolveUserId(authUserId)` — the sanctioned
service-to-service cross-module call (`layering-rules.md` §2) every module needing a `created_by`
FK will reuse, resolving the internal `users.id` from the session's Supabase auth id (these are
deliberately different ids).

**A real bug found running the live demo's very first `POST /api/v1/products` call:**
`requireSession` (`src/core/auth/session.ts`) threw `401 — Session has no tenant_id claim` even for
a freshly-onboarded, refreshed session whose JWT genuinely carried the claim. Root cause: the
Custom Access Token Hook injects `tenant_id` as a **top-level** JWT claim
(`supabase/sql/001_custom_access_token_hook.sql`: `jsonb_set(claims, '{tenant_id}', ...)`, read back
by `current_tenant_id()`'s SQL as `auth.jwt() ->> 'tenant_id'`) — but `requireSession` read
`user.app_metadata.tenant_id` instead, a field that doesn't exist for a custom top-level claim.
This bug had been present since Sprint 01 and sat invisible through Sprint 01, 02, and 03 for one
specific reason: `POST /api/v1/onboarding` deliberately uses the *other* function in the same file,
`requireAuthenticatedUser` (tenant-agnostic by design, since onboarding runs before a tenant_id
exists) — so `requireSession` itself had never actually been called by a real request until this
sprint's `POST /api/v1/products`, the first endpoint requiring a tenant-scoped session at all. Fixed
by decoding the already-verified token's payload directly for the top-level claim, rather than
trusting the SDK's `User.app_metadata` field. Recorded as its own retrospective entry
(`retrospective-log.md`) since it's a third instance of the same underlying shape (Sprint 01:
"verified locally" ≠ "CI-ready"; Sprint 02: "service-layer tested" ≠ "HTTP endpoint works"; this:
"one function in a file being proven live" ≠ "every function in that file being proven live") — new
concrete practice adopted: `core/` files with multiple exports now state each export's own proof
status in its docstring, applied immediately to both functions in `session.ts`.

**Demo run 2026-08-01, all 7 steps passed** against live production Supabase via real HTTP requests
to a local dev server (not direct service calls): create (201), idempotent replay (same row, no
duplicate), missing-name validation (422), missing-auth (401), and a live cross-tenant RLS proof
(tenant B denied reading tenant A's product). Test fixtures cleaned up after — including 4 orphaned
tenant rows left behind by two earlier failed script attempts (before the `requireSession` fix and
before switching from `signUp` to `admin.createUser` to work around this Supabase project's
email-confirmation requirement) — database confirmed at 0 rows across `tenants`/`stores`/`users`/
`products` afterward.

## 2026-08-02 — Sprint 05: `POST /api/v1/sales` built and demoed live; no new bug found

Planning found two real gaps before writing code, both against already-approved documents:
`sales.md`'s full `POST /sales` contract requires `trading_day_id` (Trading Day is M2 scope, not
built) and tax/discount/split-payment fields (M1/M2); separately,
[WF-002](../06-workflows/sales-workflows.md#wf-002--complete-a-single-item-cash-sale) requires the
stock-ledger movement atomically with the sale, but that's backlog.md's own item 7, a later sprint
depending on this one. Both resolved the same way Sprint 02/04 resolved their own spec gaps: dated
correction notes in `sales.md`, a new `docs/modules/pos/specification.md` scoped honestly to
cash-only/no-discount/no-tax, and the gap against WF-002's atomicity requirement named directly
rather than silently produced.

**Built:** `Sale`/`SaleLineItem`/`SalePayment` Prisma models (M0-minimal columns — no
`trading_day_id`/`device_id`/`customer_id`/tax/discount), migration
`20260801153106_add_sales_m0_minimal` applied live, RLS (`supabase/sql/005_rls_sales.sql`) applied
live (`sale_line_items`/`sale_payments` have no independent RLS, matching `schema-server.md`'s own
design — access is via `sale_id`). `POST /api/v1/sales` recomputes every line's total from the
product's **current** `price_minor_units` (never the client-submitted figure, per
`api-principles.md §7`) and rejects a stale price with `PRICE_MISMATCH`; validates the single cash
payment equals the computed grand total exactly, rejecting a mismatch with the new
`PAYMENT_AMOUNT_MISMATCH` code; and is idempotent on the client-generated `id` — a replay returns
the original sale directly, skipping recompute entirely, so a price that legitimately moved *after*
a first success can never turn a legitimate retry into a spurious rejection.

**A transient local environment issue, not a code bug:** three consecutive `prisma db execute`
attempts against `DIRECT_URL` (session-mode pooler) hung and had to be killed, after having applied
a migration successfully moments earlier on the same connection string. Root cause: each hung
attempt held a pooler connection open without releasing it, and the session-mode pooler has a small
connection-slot limit — by the third attempt the pool was exhausted, so even a trivial `select 1`
hung. Resolved once the earlier hung processes were confirmed terminated (`Get-CimInstance
Win32_Process` showed them already gone by the time this was investigated — the Bash tool's own
timeout had SIGTERM'd them). Distinct from the previously-documented "`prisma db execute` hangs on
*transaction*-mode URLs" CLI quirk — this was a real, if self-inflicted, connection-pool exhaustion
on the *session*-mode URL that normally doesn't hang at all.

**Demo run 2026-08-02, all 9 steps passed** against live production Supabase via real HTTP requests:
create (201, server-computed total), idempotent replay, a stale-price rejection
(`PRICE_MISMATCH`), a payment-mismatch rejection (`PAYMENT_AMOUNT_MISMATCH`), an unknown-product
rejection (`NOT_FOUND`), and a live cross-tenant RLS proof. **No new bug found** — notable because
this is `requireSession`'s second real caller since Sprint 04's fix, and it held. Test fixtures
cleaned up after; database confirmed at 0 rows across every table touched.

**A named, not-yet-acted-on risk:** this is the third sprint in a row (03, 04, 05) that defers the
actual mobile Flutter UI in favour of a backend-only slice. Each deferral was independently correct
scope discipline, but flagged explicitly in `sprint-05.md`'s Risks section as worth weighing head-on
when Sprint 06 is planned, rather than let the pattern compound silently — the M0 exit criterion
(backlog.md item 11) genuinely needs a working mobile app eventually.

## 2026-08-02 — Sprint 06: mobile sign-in — the first real Flutter screen

Planning found a real gap in `backlog.md`: item 11's end-to-end proof requires "sign in" as its
first step, but no backlog item had ever decomposed the mobile sign-in screen itself — added as
item 12 (dated correction, `backlog.md` 0.2.0), the concrete first action against the
three-sprints-running mobile-UI-deferral risk `sprint-05.md` named.

**Built:** `apps/mobile/lib/features/authentication/` (domain/data/presentation layers per
`mobile-structure.md`), `core/auth/session.dart` (session primitives shared by every feature),
`core/config/env.dart` (build-time config, `String.fromEnvironment`, fails loudly if unset — see
[ADR-0010](../adr/ADR-0010-mobile-config-via-dart-define.md), the first architecturally-significant
mobile decision this project has needed). `app/router.dart` now guards every route: signed out →
`/auth/login`, signed in → `/`, reactive via a `GoRouterRefreshStream` bridging Supabase's
auth-state stream to `go_router`'s `refreshListenable`. `app/theme.dart`'s placeholder indigo seed
colour — explicitly flagged in its own docstring as temporary "until a real screen consumes it" —
replaced with `foundations.md`'s actual `#0F6B5C` seed, since this sprint is that trigger event.

**A real bug found and fixed before it shipped, not in production:** the `SignInController`
(`AsyncNotifier<void>`)'s `build()` was originally written `async`, which meant the controller
started in `AsyncLoading` for one frame on every screen load — before the user had done anything —
because an `async` function body always resolves via a microtask even with nothing to await.
Caught by a widget test expecting the submit button enabled immediately, not by manual inspection.
Fixed by making `build()` synchronous (`FutureOr<void> build() {}`, no `async`), which returns
immediately rather than via a microtask.

**Two genuine environment gaps, recorded in full in `sprint-06.md`'s Demo script and
`retrospective-log.md`'s Sprint 06 entry:** the C: drive hit 0 bytes free mid-sprint from
accumulated package-manager caches (resolved with the founder's confirmation before clearing
anything); and no local device can actually run the mobile UI (Windows desktop missing its C++
workload, no Android SDK) — discovered only when the demo needed a real device. Worked around by
proving the real `SupabaseAuthRepository` production code against live Supabase Auth via a
temporary `flutter run -d chrome` script (session created and cleared correctly, wrong password
correctly rejected as `AuthFailure`), separately from the screen's own UI behaviour (8 widget tests
against a fake repository) — a legitimate but honestly-logged substitute for one single end-to-end
run, not claimed as equivalent to it.

**Demo run 2026-08-02:** a real, previously-onboarded Supabase Auth user (created via the same
`POST /api/v1/onboarding` pattern prior sprints used) signed in and out successfully against
production Supabase; a wrong password was correctly rejected. Test fixtures (tenant, store, user,
Supabase Auth account) deleted afterward, confirmed at 0 rows.

## 2026-08-02 — Sprint 07: mobile product creation — the local write path

Closes backlog item 5's remaining, mobile-only scope (the server half shipped Sprint 04) — the
second concrete action against the mobile-UI-deferral risk. Found one real gap while planning:
`route-map.md` had a route for viewing/editing an existing product (`/catalogue/:id`) but none for
creating a new one — added `/catalogue/add` as a dated correction (`route-map.md` 0.1.2) before
writing the screen.

**Built:** `apps/mobile/lib/features/catalogue/` (domain/data/presentation, per
`mobile-structure.md`). `DriftProductRepository.createProduct` writes the local `products` row and
enqueues a `product.create` operation to `outbound_queue` inside a single Drift transaction —
payload identical to `POST /api/v1/products`'s own request shape (`{ id, name, price_minor_units }`),
matching `sync-api.md §1`'s "push does not define a second, parallel request schema" so the future
sync engine can hand the queued payload straight to the same service logic the direct endpoint uses.
Idempotent on `id`. `AddProductScreen` at `/catalogue/add`, reached via a FAB on the home screen.

**Two environment issues hit and resolved, neither a code bug:**
- The C: drive's free space had not been an issue since Sprint 06's cache cleanup, but mid-sprint
  `flutter analyze` crashed outright with "Could not reserve virtual memory" — the machine's RAM was
  down to 0.7 GB free (of 15.67 GB), traced to 33 leftover Chrome processes (~3.2 GB) that outlived
  Sprint 06's `flutter run -d chrome` demo despite the wrapper task having been stopped. Resolved by
  the founder closing Chrome directly, since distinguishing "leftover demo instance" from "the
  founder's actual open tabs" isn't safely inferable from a process list alone — asked rather than
  guessed. **New standing note:** a `flutter run -d <device>` launched for a demo can leave the
  browser/process running even after its wrapper task is stopped; verify no such process survives
  after wrapping up, not just that the launching task exited.
- A real name collision: Drift generates a row class literally named `Product` for the `Products`
  table, colliding with this feature's own domain `Product` entity — surfaced immediately by
  `flutter analyze` (`ambiguous_import`), fixed with a scoped `hide Product` on the database import.

**Live verification (no local device can run the actual rendered UI, same gap Sprint 06 found):** a
temporary script used a real file-backed `NativeDatabase` (not `.memory()`), wrote a product, closed
the connection, reopened a **fresh** connection to the same file, and confirmed both the `products`
row and the `outbound_queue` row were present and correct — proving genuine on-disk persistence, not
just an open connection's in-memory cache. An idempotent replay against the reopened connection
correctly wrote nothing new. 16 tests (3 new repository tests, 5 new widget tests, 8 carried over
from Sprint 06) all pass; `flutter analyze` clean.

## 2026-08-02 — Sprint 08: store context — the till screen's real prerequisite

Found while planning Sprint 08 (originally scoped as the till screen itself): the till screen
(backlog item 6) cannot create a sale without a `store_id`, and nothing built through Sprint 07
ever gave the device one — the JWT carries `tenant_id` (a device's tenant, per the Custom Access
Token Hook) but not `store_id`, since a tenant can have multiple stores by design (ADR-0003) even
though V1 only ever creates one. Added backlog item 13 (dated correction, `backlog.md` 0.3.0) and
scoped this sprint to it alone, deferring the till screen itself to the next sprint — the same
"find the real prerequisite, build it as its own sprint" pattern Sprint 06 already established for
mobile sign-in.

**Built (backend):** `apps/web/src/modules/stores/` (new module folder) — `GET /api/v1/stores`,
already documented in `identity.md` and named in `company-store-setup/specification.md §4` as "not
yet implemented," so no new specification was needed. Returns `{ data: [{ id, name, address }],
next_cursor: null }`, tenant-scoped via the RLS policy Sprint 02 actually shipped
(`supabase/sql/003_rls_stores.sql`) — found and fixed a **stale doc claim** in the same pass:
`company-store-setup/specification.md §3` still said "Not yet built: RLS on stores," true only
until Sprint 02 shipped it and never corrected since.

**Built (mobile):** `apps/mobile/lib/core/network/` (a bare Dio client with a bearer-token
interceptor reading the current Supabase session — the first mobile call to this project's own
backend, not just Supabase Auth) and `core/store_context/` (`StoreContextRepository`: cache-first
read from a new local `StoreContext` Drift table, one-row read cache per `schema-local.md`'s
`shop_settings` precedent — never written to `outbound_queue`, since it isn't an entity that syncs).
Wired into the home screen alongside the existing local-database status text.

**Live verification:** a temporary script (real Supabase, deleted after) onboarded tenant A,
re-signed-in for a fresh token (the pre-onboarding token predates the `tenant_id` claim — the same
gotcha every prior demo script has had to work around), and confirmed `GET /stores` returns exactly
tenant A's own store. Onboarded tenant B and confirmed its session never sees tenant A's store — the
cross-tenant RLS proof this endpoint's contract has needed since it was first documented, now
actually run. 9/9 checks passed on the first try. Mobile: 4 repository tests against a fake fetch
function prove cache-first behaviour, cache overwrite on refresh, and a thrown error on an empty
server response — no real device needed for this half, unlike Sprints 06/07's UI work.

**A real bug found on the first live attempt, fixed immediately:** the demo script's first version
reused the pre-onboarding sign-in token for the `GET /stores` call and got
`UNAUTHENTICATED — Session has no tenant_id claim` — not an endpoint bug, a script bug (the Custom
Access Token Hook stamps `tenant_id` at mint/refresh time, not retroactively onto an
already-issued token). Fixed by re-signing-in after onboarding, same pattern Sprint 04/05's scripts
already used for exactly this reason.

## 2026-08-02 — Sprint 09: mobile till screen, the local write path, and ADR-0008's local half

**What landed:** `apps/mobile/lib/features/pos/` — cart state (`CartController`), the till screen
(`/pos`), and `DriftSaleRepository.completeSale()` writing `sales`/`sale_line_items`/`sale_payments`
and enqueuing to `outbound_queue` atomically (a forced-failure test proves the whole transaction
rolls back together). `InvoiceNumberGenerator` implements ADR-0008's local half
(`{device_short_id}-{financial_year}-{sequence}`, April 1 rollover) and the new `core/money/Money`
class. Verified via `flutter test` against a real Drift database (52 tests total, up from 44).
**A real environment gap, not a code bug**, found while preparing to run this on the founder's own
device for the first time: no Android SDK/NDK/JDK existed on this machine at all — installed via
`sdkmanager` cmdline-tools (not full Android Studio), plus a Kotlin cross-drive incremental-compiler
crash (`kotlin.incremental=false`) and a Gradle daemon OOM on a memory-constrained 16GB machine
(`-Xmx8G` reduced to `-Xmx2G`), both fixed in `apps/mobile/android/gradle.properties`.

**Retroactive log entry, added 2026-08-13:** this sprint's own DoD checked "implementation-log
updated," but the entry itself was never actually written — found while adding Sprint 11's own
entry and reading back through this file's Change Log table, which jumped straight from 0.14.0
(Sprint 08) past Sprint 09/10 to Sprint 11. Named honestly rather than silently backfilled without
comment; see [sprint-09.md](../17-sprints/sprint-09.md) for the sprint's own full record, which was
written correctly at the time.

## 2026-08-12 — Sprint 10: mobile sales history, and the first real founder device/account

**What landed:** `apps/mobile/lib/features/sales_history/` — `/sales-history` and
`/sales-history/:id`, reading local-only from Sprint 09's own `sales`/`sale_line_items` tables via
two new `SaleRepository` methods (`listCompletedSales`, `getSaleDetail`). A founder-directed
insertion of Sales & Invoices' minimal slice, ahead of its M1 grouping, triggered directly by the
founder's own first hands-on test of the till screen on their real phone ("it works fine, but no
sell history") — see [modules/README.md](../modules/README.md) Rule 2's second named exception.
This sprint is also the project's first contact with a real device end to end: USB and wireless
debugging both proved unreliable against the founder's phone (a Redmi 15C never exposing a working
ADB interface), so a standalone APK was built and side-loaded instead, via a temporary local file
server. A real, non-throwaway founder account ("Gadgets Kolkata") was created for this — the first
account in this project not deleted after its demo. The APK link initially failed after a rebuild
because the file server cached the old build's `Content-Length` at startup instead of re-`stat`ing
per request — fixed and reconfirmed working.

**Retroactive log entry, added 2026-08-13** — same gap and same reasoning as Sprint 09's entry just
above; see [sprint-10.md](../17-sprints/sprint-10.md) for the sprint's own full record.

## 2026-08-13 — Sprint 11: the stock ledger (M0 item 7)

**What landed:** `stock_movements` (M0-minimal columns — no `device_id`, matching `sales`' own
precedent; `created_by` substitutes for attribution), migration
`20260812192621_add_stock_movements_m0_minimal` applied live, RLS
(`supabase/sql/006_rls_stock_movements.sql`) applied live. `POST /api/v1/products` gained an
optional `initial_quantity`, writing one `opening` movement in the same `prisma.$transaction` as the
product row (idempotent via a shared id — the movement reuses the product's own id as its own,
since it's a genuine 1:1 relationship). `POST /api/v1/sales` writes one `sale` movement per line
item, also inside an explicit transaction — no FK relation exists from `sales` to `stock_movements`
(schema-server.md links them only loosely via `reference_type`/`reference_id`), so Prisma's
nested-relation-write sugar didn't apply here the way it does for `sale_line_items`/`sale_payments`.

Since `products` has no `store_id` of its own (M0-minimal, tenant-scoped only) but
`stock_movements` is store-scoped by design, `stores.getPrimaryStoreId(tenantId)` was added,
resolving the tenant's one store server-side (ADR-0003) — never accepted from the request, matching
`inventory.md`'s own stated principle for stock-movement writes generally.

**Live-verified against the real database**, throwaway tenants deleted after: opening-movement
creation and idempotent replay, a real sale movement with the correct signed delta and
`reference_id`, a genuine oversell (20 units against a balance of 7) succeeding rather than being
rejected — DR-005 proven, not just asserted — and a cross-tenant RLS proof reading
`stock_movements` directly via PostgREST. 16/16 checks passed on the first run; no new bug found.

**A real documentation gap found and fixed in the same pass:** this file's own Change Log had never
recorded Sprint 09 or Sprint 10 at all, despite both sprints' own DoD checklists claiming
"implementation-log updated." Backfilled above with a note explaining why, rather than silently
inserted as if it had always been there.

## 2026-08-13 — Sprint 12: the audit log (M0 item 8)

**What landed:** `audit_log` (the full schema-server.md column shape — this table was already this
narrow in the approved design), migration `20260812195944_add_audit_log_m0_minimal` applied live,
RLS (`supabase/sql/007_rls_audit_log.sql`) applied live. `POST /api/v1/sales` writes exactly one
`audit_log` row (`action = 'sale.completed'`, `entity_type = 'sale'`) inside the same
`prisma.$transaction` Sprint 11 already established for the sale's stock movements — reusing the
sale's own id as the audit row's id, the same 1:1 idempotency-key pattern Sprint 11 used twice over.
`before_state` is always `null` this sprint (a creation event has no prior state); `after_state`
snapshots the sale's own computed totals.

**Live-verified against the real database**, throwaway tenants deleted after: the entry's exact
shape (action/entity/actor/store/before/after), idempotent replay producing no second row, and a
cross-tenant RLS proof reading `audit_log` directly via PostgREST. 11/11 checks passed, no new bug.

**A real, now-visible gap named, not fixed:** audit-model.md §1 lists ten trigger types; this
sprint covers exactly one (`sale.completed`). Sprint 11's own `stock_movements` rows — audit-model.md
§1's own first-listed trigger — have had, and continue to have, zero audit coverage. Named directly
in `audit-log/specification.md §1` as the concrete next candidate, not silently absorbed into this
sprint's own narrower, already-estimated scope.

## 2026-08-13 — Sprint 13: the sync engine's backend half (M0 item 9)

**What landed:** `apps/web/src/modules/sync/` (new module) — `POST /api/v1/sync/push` and
`GET /api/v1/sync/pull`, the backend-only half of backlog.md item 9, matching the same
alternating backend/mobile split already established for products (Sprint 04/07) and sales
(Sprint 05/09). Push dispatches each operation to the **exact same service function** its direct
endpoint already calls (`products.service.createProduct`, `pos.service.createSale`) — no new
idempotency mechanism, per sync-api.md §5; processes `product.create` before `sale.create`
regardless of submitted order (the six-group ordering collapsed to two, since no other operation
type has a client-facing write path yet); remaps a sale's `NOT_FOUND` (missing product) to
`DEPENDENCY_NOT_FOUND`, the one place its error handling genuinely diverges from the direct
endpoint. Pull is this codebase's first cursor-paginated endpoint (`GET /stores` never needed one —
exactly one store per tenant), `(updated_at, id)` on `products` only.

**A real bug found on the first live attempt, fixed immediately:** the pull cursor's `next_cursor`
came back non-null on a genuinely final page — a classic off-by-one. The repository fetched exactly
`limit` rows, so "exactly filled the page" was indistinguishable from "filled the page, and more
exists after it." Fixed by fetching `limit + 1` as a peek and trimming the extra row before
returning; its presence, not the returned count, is what actually answers the question. Caught by
the demo script's own two-page walk, not by unit tests (which had mocked the repository and so
never exercised the real off-by-one at all) — the same shape of finding this project's "real HTTP
request/live verification required" addendum rule exists to catch.

**Live-verified against the real database**, throwaway tenants deleted after: a `sale.create`
submitted *before* its own `product.create` in the same batch still succeeds (proving the
reordering actually runs, not just that unordered batches happen to work);
`DEPENDENCY_NOT_FOUND` for a genuinely missing product; idempotent replay of an already-accepted
batch; a corrected two-page cursor walk; cross-tenant isolation on pull. 14/14 checks passed.

**Named, not built:** no mobile sync trigger exists yet — the outbound queue still isn't drained,
so on-device writes remain local-only until the next sprint wires a client to call these endpoints.

## 2026-08-13 — Sprint 14: the sync engine's mobile half (M0 item 9, in full)

**What landed:** `apps/mobile/lib/core/sync/` — `SyncRepository.syncNow()` pushes every `queued`/
`failed_retrying` `outbound_queue` row via the exact same `pushSyncOperations` call Sprint 13's
backend accepts, then updates each row's own `status`/`attempt_count`/`rejection_reason` from its
push result (`synced`, `failed_retrying` + incremented `attempt_count` for
`DEPENDENCY_NOT_FOUND`, or `rejected` + a reason for anything else) — never touching a row unless a
server response actually named it. Then pages `GET /sync/pull` for `products`, upserting every row
into the local cache. Triggered automatically once per app session (a cached `FutureProvider`,
right after `storeContextProvider` resolves) plus a manual "Sync now" button on the home screen.

**A real, deliberate design trade-off, named rather than defaulted into:** the obvious next step —
persisting the pull cursor between sync runs, matching the backend's own resumable design
(sync-api.md §6) — was not built. Doing so would have meant a new local table and a Drift schema
migration, and this is the first mobile sprint where that carries real risk: the founder's phone
has a persistent, non-throwaway installed app with real data since Sprint 10, unlike every prior
mobile sprint's throwaway-fresh-install assumption. Every `syncNow()` call instead pages `products`
from the start each time — fine at M0's dataset size, revisited if it ever isn't.

**Verified:** `flutter test`, 60/60 (52 before this sprint) — 7 new `SyncRepository` tests against a
real in-memory Drift database (accepted/pending/rejected status transitions, batch composition,
empty-queue short-circuit, multi-page pull, upsert-not-duplicate) and 1 new widget test (the home
screen's sync status line and "Sync now" button). `flutter analyze` clean. No real device needed —
same reasoning Sprint 09/10's own repository tests already established, since nothing in this
sprint's DoD required proving it against a physical phone.

## 2026-08-13 — Sprint 15: Bluetooth ESC/POS receipt printing (M0 item 10)

**What landed:** `apps/mobile/lib/features/receipt_printing/` — `ReceiptFormatter` (pure Dart,
builds a `ReceiptDocument` from a `SaleDetail` + shop name, narrowed to what M0's local cache
actually has: shop name only in the header, no address/GSTIN/cashier name/discount/tax/split
payment), `EscPosReceiptEncoder` (real ESC/POS byte generation via `esc_pos_utils_plus`,
`PaperSize.mm58`), and `BluetoothPrinterRepository` (wraps `print_bluetooth_thermal`'s connect/
write/disconnect behind an injectable interface, always disconnecting even on a write failure or a
thrown error). A `print` action on `/sales-history/:id` opens a printer picker listing every
paired Bluetooth device and surfaces the result via `SnackBar`. Android manifest gained
`BLUETOOTH`/`BLUETOOTH_ADMIN`/`BLUETOOTH_CONNECT`/`BLUETOOTH_SCAN`, matching
`print_bluetooth_thermal`'s own documented requirement (verified against its example manifest, not
guessed).

**A real, explicitly named verification gap, not glossed over:** this sprint cannot, and does not
claim to, prove the receipt prints correctly on a physical thermal printer —
[manual-test-scripts.md — MTS-01](../14-testing/manual-test-scripts.md#mts-01--thermal-printer--both-widths-real-hardware)
needs real Bluetooth ESC/POS hardware, which doesn't exist in this environment. Same category as
[device-matrix.md §3](../14-testing/device-matrix.md#3-this-is-a-founder-action-not-an-engineering-one--stated-plainly)'s
already-established "founder action, not an engineering one" precedent for the physical reference
device. Everything short of ink-on-paper is built and tested for real: the ESC/POS byte stream is
generated by the actual `esc_pos_utils_plus` library (not hand-rolled), and its content is asserted
against the real encoded bytes, not mocked.

**Verified:** `flutter test`, 75/75 (60 before this sprint) — 5 formatter tests (pure Dart), 3
encoder tests (real ESC/POS encoding via `TestWidgetsFlutterBinding.ensureInitialized()`, since
`CapabilityProfile.load()` reads a bundled asset), 7 Bluetooth-repository tests (injected fakes —
there is no real Bluetooth adapter in CI or this dev machine to test against directly).
`flutter analyze` clean. This is the first M0 module with zero backend component.

## 2026-08-13/14 — Sprint 16: M0's end-to-end proof (item 11), steps 1–7

**What landed:** no new app code — item 11 exercises capabilities already built across Sprints
01–15. Wrote the exact step-by-step script for
[milestones.md — M0](../16-milestones/milestones.md#m0--walking-skeleton)'s exit criterion, cross-
referenced against the actual screens/providers each step touches (`autoSyncOnStartProvider`'s
`sync_status` line as the concrete "watch it sync" signal, rather than an ambiguous instruction).
Rebuilt the release APK carrying every Sprint 11–15 change and re-served it via the same local file
share Sprint 10 established.

**Confirmed 2026-08-14:** the founder ran steps 1–7 (sign in, airplane mode, add a product, sell
it, reconnect, sync) on the real "Gadgets Kolkata" account and device. Worked cleanly — no crash,
no hang, both the product and the sale reached the server. **No new bug found** — worth recording
precisely because this is the first time every individually-proven Sprint 01–14 piece has run
together as one real sequence, and unlike several of those sprints' own first-real-contact
findings (Sprint 04's `requireSession` bug, Sprint 10's file-server `Content-Length` bug), nothing
broke at the seams this time.

**Still open:** step 8 (printing the physical receipt) — blocked on Bluetooth ESC/POS printer
hardware, which the founder confirmed 2026-08-13 they don't yet have. M0 itself stays open until
this closes too; tracked in [sprint-16.md](../17-sprints/sprint-16.md), not silently dropped.

**A real process decision, asked and answered rather than assumed:** with M0's last open item
blocked purely on hardware neither side controls, the question of whether M1 should begin now or
wait was put to the founder directly (not decided unilaterally, since it means bending
`modules/README.md` Rule 2's own literal wording — "M1 onward builds one row at a time" presumes M0
is actually done first). Founder chose to start M1 now. Recorded as Rule 2's third exception, not a
silent reinterpretation.

## 2026-08-14 — Sprint 17: Categories, the first M1 module

**What landed:** [backlog.md's M1 decomposition](../17-sprints/backlog.md#2-m1--fully-decomposed-2026-08-14-now-that-m0-has-reached-this-point)
(8 items, 15.5 person-days, matching M0's own decomposition depth) written in the same pass as this
sprint's own planning. `categories` table (full column list — this table needed no M0-minimal
narrowing) + RLS, `POST`/`GET /api/v1/categories`, matching every prior M0 creation/list endpoint's
own idempotency and cursor-pagination mechanisms exactly — no new pattern invented. Deliberately
narrow, matching Products' own Sprint 04 precedent: create+list only, no `PATCH`/`DELETE` (which
would need a state-transition idempotency mechanism — `client_operation_id` + `idempotency_keys` —
that doesn't exist anywhere in this codebase yet, every M0 mutation having been a creation), no
permission enforcement (Roles & Permissions is deliberately the last M1 item, per
dependency-graph.md §3's "woven through every node, not sequential" framing).

**Live-verified against the real database**, throwaway tenants deleted after: idempotent creation,
a corrected cursor-pagination walk (built with the peek-ahead fix from the start, rather than found
live a second time), and a cross-tenant RLS proof. 9/9 checks passed, no new bug.

**First module under M1's own governance:** Rule 2 ("one module at a time") applies literally
again from this sprint onward — no exception needed or invoked, unlike every M0 sprint.

## 2026-08-14 — Sprint 18: Units, the second M1 module

**What landed:** `units` table (full column list — `id`, `tenant_id`, `name`, `symbol`,
`allows_fractional`, `created_at`, `created_by`) + RLS, `POST`/`GET /api/v1/units`, built as a
direct sibling of Sprint 17's Categories module — identical idempotent-creation and peeked-cursor
pagination mechanisms, no new pattern invented, no dependency on Categories itself. Deliberately
narrow, same scope cut as Categories: create+list only, no `PATCH`/`DELETE` (same missing
state-transition idempotency mechanism named in Sprint 17), no permission enforcement.
`allows_fractional`'s immutability rule (`UNIT_FRACTIONAL_FLAG_LOCKED`) is named in the
specification but enforces nothing yet — there is no `PATCH` and no `products.unit_id` for it to
protect against.

**Live-verified against the real database**, throwaway tenants deleted after: idempotent creation,
a correctly-peeked cursor-pagination walk, and a cross-tenant RLS proof. 9/9 checks passed, no new
bug — the first sprint in this project to reuse a prior sprint's module shape almost verbatim.

## 2026-08-14 — Sprint 19: extend Products with category_id/unit_id/sku/barcode/hsn_sac_code

**What landed:** `products` extended with `category_id`, `unit_id` (nullable FK, existence-
validated against the caller's own tenant), `sku`, `barcode` (each unique per tenant), and
`hsn_sac_code`. `POST /api/v1/products` accepts all five as optional. Added `SKU_ALREADY_ASSIGNED`
(catalogue.md/error-catalogue.md) as the sibling of the pre-existing `BARCODE_ALREADY_ASSIGNED`,
rather than let a real sku collision surface as an unhandled 500.

**Real, dated correction found before writing any code:** backlog.md item 3 said these fields
should be `NOT NULL`/required, matching FR-032's literal wording. Querying the live production
database first (a five-minute check, not an afterthought) found 4 real products already created —
from Sprint 16's own founder-run device proof — with no category or unit. Making the columns
`NOT NULL` today would have failed the migration outright or demanded a backfill with no
authorised default value, and making the *API* fields required would have 422-rejected the
founder's own already-working mobile app (which still can't supply them — `/catalogue/add`'s
category/unit picker is backlog item 4, not built yet) on its very next product creation. Shipped
optional instead; the "required" half of FR-032/FR-035 stays a named, open gap for a follow-up
sprint once item 4 exists to actually supply real values.

**Live-verified against the real database**, throwaway tenants deleted after, including the
regression check this sprint cared about most: the exact `{id, name, price_minor_units}` shape
mobile already sends still returns `201` with every new field `null`. Also verified: full-shape
creation, idempotent replay, `NOT_FOUND` for a missing/cross-tenant `category_id`/`unit_id`,
`BARCODE_ALREADY_ASSIGNED`/`SKU_ALREADY_ASSIGNED` on a same-tenant collision, and that the same
barcode is accepted for a different tenant (uniqueness is per-tenant, not global). 9/9 checks
passed, no new bug.

## 2026-08-14 — Sprint 20: mobile catalogue UI (Categories/Units screens, Products updated)

**What landed:** `/catalogue/categories` and `/catalogue/units` — list-plus-create-dialog screens,
reachable from the home screen; `/catalogue/add` extended with required Category/Unit dropdowns.
Local `Categories`/`Units` Drift tables (read caches) and nullable `category_id`/`unit_id` columns
added to the local `Products` table — this project's **first-ever local schema migration**
(every prior sprint shipped `schemaVersion: 1`; the founder's real device already has real local
data from Sprint 16, so this had to be a genuine non-destructive `MigrationStrategy.onUpgrade`,
not a reinstall-and-recreate).

**Real design gap found before writing code, resolved by reusing an existing precedent, not
inventing a new one:** the sync engine (`sync-api.md`) has exactly two push operation types —
`product.create`/`sale.create`. Building `category.create`/`unit.create` would have been real,
unbudgeted backend scope. Instead, category/unit creation calls the server directly
(`POST /api/v1/categories`/`/units`, both already live since Sprint 17/18) and caches the result
locally only on success — exactly the shape `schema-local.md`'s own `shop_settings` row already
documents ("write path exists but is not offline-capable"). Reads are offline-capable (the local
cache); writes require connectivity. Corrected in `categories/units/specification.md §7`,
`schema-local.md`, and `route-map.md`, rather than silently overclaiming full offline CRUD.

`/catalogue/add`'s new category/unit requirement is UI-level only — `ProductRepository
.createProduct`'s domain interface now requires both, but the server's own `POST /api/v1/products`
still accepts them as optional (Sprint 19). The `product.create` sync-push payload now carries real
values; no backend change was needed since Sprint 19 already accepts them.

`flutter analyze` clean; `flutter test` 89/89 (4 new repository tests × 2 entities, plus 2 new
screen test files, plus the existing `drift_product_repository_test.dart`/
`add_product_screen_test.dart` updated for the new required fields) — no new bug found, and the
Drift multi-instance warning across test files remains the same benign, debug-only false positive
noted in prior sprints.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | First entry: Sprint 01 repository scaffold and Auth wiring, verified locally; the circular-FK finding and the packageManager-guess lesson recorded; three founder-blocked items named precisely. |
| 0.1.1 | 2026-07-31 | GitHub remote blocker resolved — repo created and both commits pushed to `main`; branch protection and Vercel connection remain as the two still-outstanding founder actions. |
| 0.2.0 | 2026-08-01 | Live Supabase project connected; direct-connection IPv6 issue diagnosed and worked around via pooler; the transaction-mode-pooler `db execute` hang traced to a CLI-specific incompatibility, not a real connectivity problem (confirmed via actual `PrismaClient`); schema migration applied with the hand-edited deferrable circular-FK fix; Custom Access Token Hook function applied — both verified live. Dashboard hook wiring is the only thing left blocking the demo script. |
| 0.3.0 | 2026-08-01 | Founder wired the Dashboard hook; demo script run end-to-end and passed (JWT `tenant_id` claim correct, cross-tenant read denied). Two real findings surfaced and fixed: the hook function needed `security definer` (500 on sign-in otherwise), and `ON DELETE RESTRICT` silently cannot be deferred in Postgres even when marked `DEFERRABLE INITIALLY DEFERRED` (fixed via a follow-up migration, changed to `NO ACTION`). RLS enabled on `tenants`/`users`. Branch protection and Vercel connection are the only two remaining founder actions. |
| 0.4.0 | 2026-08-01 | `gh` CLI installed and authenticated; repo visibility resolved (public, since GitHub free tier blocks branch protection on private repos); branch protection applied to `main`; PR #1 opened, found and fixed two real CI-only gaps (missing `packageManager` pin, `next-env.d.ts` eslint false-positive), passed all checks, merged. Sprint 01 fully closed. |
| 0.5.0 | 2026-08-01 | Sprint 02 planning found and closed a real specification gap predating it: no approved module specification existed for Authentication (despite live Sprint 01 code) or Company & Store Setup, and Phase 11 never specified the signup/onboarding endpoint. All three written/added; `modules/README.md`'s Rule 2 amended with a named M0 exception after finding it contradicted Phase 18's own "M0 is the first module" framing. |
| 0.6.0 | 2026-08-01 | Sprint 02 implemented and demoed live: `POST /api/v1/onboarding`, RLS on `stores`, 6 unit tests, all 6 demo steps passed against the real database. Found and fixed a real row-ordering bug (`stores_created_by_fkey` is an ordinary FK, not part of the deferred pair) on first contact with live data. |
| 0.7.0 | 2026-08-01 | This PR's own CI run found two more real gaps: `lint-typecheck`/`unit-tests` never ran `prisma generate` (only `build` did), and the `gh` token needed the `workflow` scope added to push a workflow-file fix. Both resolved; PR merged. Vercel's preview deployment fails on this branch for an unknown reason — not a required check, so it didn't block merging, but flagged as a real open item needing Vercel access to diagnose. |
| 0.8.0 | 2026-08-01 | Vercel fixed at the root (`prisma generate` moved into the `build` script itself) and verified live. Founder-provided Vercel token used to diagnose, fix, and set the same 5 env vars as `.env.local`. Deploying it live led to the first-ever real HTTP request against this endpoint, which surfaced two real bugs invisible to every check run so far: `NextResponse.next()` crashing at runtime in a Route Handler, and — much more significant — the cookie-based `@supabase/ssr` client never reading an incoming `Authorization: Bearer` header at all, meaning every real mobile-client request to any endpoint would have failed authentication. Both fixed; verified end-to-end against local dev and live production. |
| 0.9.0 | 2026-08-01 | Sprint 03: Flutter SDK installed (`D:\flutter`, stable channel, not committed), `apps/mobile` scaffolded and reshaped to `mobile-structure.md`; local Drift database built for backlog.md item 4's scope (`outbound_queue` full shape, minimal `products`/`sales`/`sale_line_items`/`sale_payments`/`stock_movements`). Two real package-version findings: `riverpod_lint`/`riverpod_generator` conflict with Riverpod 3.x + `drift_dev`, and `sqlite3_flutter_libs` is obsolete (superseded by `sqlite3` v3.x + `drift_flutter`). `flutter test` proves the schema actually opens and round-trips, not just compiles. Android SDK still not installed — deferred until a sprint needs to build/run on-device. |
| 0.10.0 | 2026-08-01 | Sprint 04: `POST /api/v1/products` built and demoed live (M0-minimal name/price only — a real spec gap against catalogue.md/FR-032/FR-035 found and resolved before writing code). Found and fixed a real, three-sprints-latent bug: `requireSession` read the `tenant_id` claim from the wrong location (`user.app_metadata` instead of the JWT's top-level claim), invisible until this sprint's endpoint was the first to actually call it. New practice: `core/` files with multiple exports state each export's own proof status. |
| 0.11.0 | 2026-08-02 | Sprint 05: `POST /api/v1/sales` built and demoed live (M0-minimal cash-only, no discount/tax/trading-day — two real spec gaps against sales.md/WF-002 found and resolved before writing code). Server-side price/payment recompute proven live (`PRICE_MISMATCH`, new `PAYMENT_AMOUNT_MISMATCH`). No new bug found — `requireSession`'s Sprint 04 fix held on its second real caller. Named the mobile-UI deferral as a three-sprints-running risk worth addressing in Sprint 06. |
| 0.12.0 | 2026-08-02 | Sprint 06: mobile `/auth/login` — the first real Flutter screen — built and verified against real Supabase Auth. Closed the missing-backlog-item gap (item 12) and made the first concrete move against the mobile-UI-deferral risk. Found and fixed a real pre-ship bug (`SignInController`'s async `build()` causing a spurious initial loading flash) via a widget test, and two real environment gaps (disk full, no runnable mobile device locally) — both logged honestly rather than worked around silently. |
| 0.13.0 | 2026-08-02 | Sprint 07: mobile product creation (`/catalogue/add`) built — local write + `outbound_queue` enqueue atomic and idempotent, verified against a real on-disk file across a fresh connection. Closed backlog item 5's remaining scope and a real route-map.md gap. Found and fixed a real `Product` name collision (Drift's generated row class vs. the domain entity) and diagnosed a real memory-exhaustion issue (33 leftover Chrome processes from Sprint 06's demo) without guessing at the fix. |
| 0.14.0 | 2026-08-02 | Sprint 08: `GET /api/v1/stores` built and verified live with a cross-tenant RLS proof; mobile fetch-and-cache built (`core/network/`, `core/store_context/`) — the first mobile call to this project's own backend. Closed a real gap found while planning the till screen (no `store_id` source existed) and a stale doc claim (RLS on `stores` was actually shipped Sprint 02, never corrected). |
| 0.15.0 | 2026-08-13 | *Retroactive.* Sprint 09: mobile till screen (`/pos`) and its atomic local write path built (`sales`/`sale_line_items`/`sale_payments` + `outbound_queue`), ADR-0008's local invoice-numbering half implemented, `flutter test` at 52 tests. First contact with real Android tooling on this machine (SDK/NDK/JDK install, Kotlin cross-drive and Gradle-OOM fixes). This row was never written at the time — added here once the gap was found during Sprint 11's own logging. |
| 0.16.0 | 2026-08-12 | *Retroactive.* Sprint 10: mobile sales-history (`/sales-history`, `/sales-history/:id`) built, local-only, a founder-directed insertion ahead of M1. First real (non-throwaway) founder account and first real-device APK install/side-load, after USB/wireless debugging both proved unreliable. Also never written at the time — same gap as 0.15.0, closed the same way. |
| 0.17.0 | 2026-08-13 | Sprint 11: M0 item 7 (stock ledger) built — `stock_movements` table + RLS, `opening`/`sale` movements written server-side inside explicit transactions with their triggering row. Live-verified: idempotent opening-movement creation, a correct sale movement, a real oversell proving DR-005, and a cross-tenant RLS proof — 16/16 checks, no new bug. Found and fixed this file's own two-sprint logging gap (0.15.0/0.16.0) in the same pass. |
| 0.18.0 | 2026-08-13 | Sprint 12: M0 item 8 (audit log) built — `audit_log` table + RLS, one `sale.completed` entry written server-side inside the same transaction as the sale and its stock movements. Live-verified: correct entry shape, idempotent replay, cross-tenant RLS proof — 11/11 checks, no new bug. Named a real, still-open gap: `stock_movements` has zero audit coverage. |
| 0.19.0 | 2026-08-13 | Sprint 13: M0 item 9's backend half (sync engine) built — `POST /sync/push` (`product.create`/`sale.create`, dependency-ordered, per-operation results) and `GET /sync/pull` (`products`, cursor-paginated, this codebase's first). Found and fixed a real cursor off-by-one bug live (a full-looking last page). 14/14 checks passed. Mobile trigger/outbound-queue drain remains the next sprint. |
| 0.20.0 | 2026-08-13 | Sprint 14: M0 item 9's mobile half built — `core/sync/` drains `outbound_queue` and refreshes local `products`, triggered automatically once per session plus a manual button. Deliberately no persisted pull cursor, avoiding a schema migration against the founder's real installed app. `flutter test` 60/60, `flutter analyze` clean. Item 9 done in full. |
| 0.21.0 | 2026-08-13 | Sprint 15: M0 item 10's software half built — Bluetooth ESC/POS receipt printing (`ReceiptFormatter`, `EscPosReceiptEncoder`, `BluetoothPrinterRepository`), a print action on `/sales-history/:id`. `flutter test` 75/75, `flutter analyze` clean. Physical-printer verification (MTS-01) named as a founder action, not run — no hardware available, matching device-matrix.md §3's own precedent. First M0 module with zero backend component. |
| 0.22.0 | 2026-08-14 | Sprint 16: M0 item 11 (end-to-end proof), steps 1–7, confirmed working by the founder — no new bug found, the first time every Sprint 01–14 piece ran together as one real sequence. Step 8 (physical print) remains open, blocked on printer hardware; M0 itself stays open until it closes. |
| 0.23.0 | 2026-08-14 | Sprint 17: first M1 module — Categories (`categories` table, `POST`/`GET /categories`) built and live-verified, 9/9 checks. M1 fully decomposed (8 items) in the same pass, founder-directed after M0's last item was confirmed blocked purely on external hardware. Rule 2 governs literally again. |
| 0.24.0 | 2026-08-14 | Sprint 18: second M1 module — Units (`units` table, `POST`/`GET /units`) built and live-verified, 9/9 checks, direct sibling of Categories. `PATCH`/`DELETE`/`UNIT_FRACTIONAL_FLAG_LOCKED` deferred for the same reason Categories' were. |
| 0.25.0 | 2026-08-14 | Sprint 19: `products` extended with `category_id`/`unit_id`/`sku`/`barcode`/`hsn_sac_code`, all optional — a dated correction against backlog.md item 3's "required" wording, found by querying live production data (4 real products, no category/unit) before writing code. Live-verified 9/9, including a regression proof that mobile's unchanged request shape still works. Added `SKU_ALREADY_ASSIGNED`. |
| 0.26.0 | 2026-08-14 | Sprint 20: mobile `/catalogue/categories`/`/catalogue/units` built, `/catalogue/add` now requires a category/unit selection. First-ever local schema migration (non-destructive `onUpgrade`). Found and corrected a real gap: category/unit creation is online-only (no sync-push type exists for either), resolved via `shop_settings`' own existing precedent rather than a new pattern. `flutter analyze`/`flutter test` (89/89) clean, no new bug. |
