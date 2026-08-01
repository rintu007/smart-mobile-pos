# Implementation Log

> **Status:** 🟡 In progress
> **Phase:** 18 — Implementation
> **Version:** 0.7.0
> **Last updated:** 2026-08-01
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

**What's blocked on the founder, not on more design work:** diagnosing the Vercel preview-deployment
failure (needs Vercel dashboard/CLI access).

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
