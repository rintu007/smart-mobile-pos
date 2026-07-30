# Implementation Log

> **Status:** 🟡 In progress
> **Phase:** 18 — Implementation
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
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
- **No GitHub remote exists yet** — branch protection, required status checks, and the PR-preview
  deployment described in [repository-setup.md](../15-github-project/repository-setup.md) and
  [cd-workflows.md](../15-github-project/cd-workflows.md) all require a real GitHub repository to
  push to, which is a founder action (creating/authorising it), not something performed from
  within this environment.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | First entry: Sprint 01 repository scaffold and Auth wiring, verified locally; the circular-FK finding and the packageManager-guess lesson recorded; three founder-blocked items named precisely. |
