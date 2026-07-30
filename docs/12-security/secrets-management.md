# Secrets Management

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Security Engineer / DevOps
> **Approved by:** _pending_

Environment variables, rotation, CI handling, and — per this phase's exit criterion — a way to
**verify** no secret reaches a client bundle rather than merely trust that no one made a mistake.

---

## 1. Inventory of actual secrets

| Secret | Where it lives | Never appears in |
| --- | --- | --- |
| Supabase service-role key | Vercel server-side environment variable (encrypted at rest by Vercel, free tier) | Any file under a client-bundled module boundary — see §3 |
| Database direct/pooled connection URLs | Vercel server-side environment variable | Client bundle; version control |
| Supabase anon (public) key | **Not actually a secret** — it is designed to be public, security enforced entirely by RLS ([tenant-isolation.md](tenant-isolation.md)); included here only to state explicitly that its presence in the client bundle is expected and correct, not a finding |
| Custom Access Token Hook's own signing/config secrets (if any, per Supabase's mechanism) | Supabase project configuration, not application code at all | Application source, client or server |

## 2. Environment variable handling

- Local development: `.env.local`, listed in `.gitignore` from the repository's first commit — a
  secret committed once remains in git history even after deletion, so this is a day-one convention,
  not a later cleanup task.
- Production: Vercel's built-in encrypted environment variable store (free, included) — never a
  secrets file deployed alongside the application code.
- CI: GitHub Actions encrypted repository secrets (free for the plan tier this project uses),
  injected only into the specific job steps that need them (the cross-tenant test suite's database
  connection, deployment steps) — never exposed to a pull-request build from an external fork,
  which is GitHub Actions' own default protection for repository secrets on `pull_request` triggers.

## 3. The build-time check — the exit criterion's actual mechanism

Per this phase's exit criterion, "no secret can reach a client bundle" is **verified by a build-time
check, not by discipline.** Two independent mechanisms, not one:

1. **Structural (import-boundary) enforcement.** The service-role Prisma client
   ([backend-structure.md](../08-folder-structure/backend-structure.md)'s `core/db`) is only ever
   imported by server-only modules. The same dependency-cruiser configuration already adopted in
   [layering-rules.md](../08-folder-structure/layering-rules.md) for feature-boundary enforcement
   gets one additional rule: nothing under a Server-Component/Route-Handler-only path may be
   imported from a `"use client"` file or from `app/(admin)/**/*.tsx` client components. A violation
   fails CI before the secret could ever be bundled, because the import itself is rejected, not
   because the value happened not to be embedded.
2. **Content scanning (defence in depth for the above).** A CI step scans the built Next.js
   client-side JavaScript bundle output for the literal known secret values (injected as CI
   variables at scan time, never hardcoded in the scanning script itself) and for high-entropy
   strings matching the naming pattern of server-only environment variables. This catches the case
   structural enforcement wouldn't — e.g. a secret accidentally interpolated into a string literal
   rather than imported as a module.

Both run on every build, not only before a release — a secret leak introduced on a feature branch is
caught in that branch's CI, not discovered only at release-candidate time.

## 4. Rotation

| Secret | Rotation trigger |
| --- | --- |
| Supabase service-role key | On suspected compromise (immediate), and on a routine schedule (target: every 90 days) once Phase 18 establishes the operational runbook for doing so without downtime |
| Refresh tokens | Rotated automatically on every use, per [identity-and-sessions.md §3](identity-and-sessions.md#3-refresh-token-reuse-detection) — not a manual process |

The exact zero-downtime rotation procedure for the service-role key (updating the Vercel environment
variable and redeploying without a request-serving gap) is a Phase 18 operational runbook item, not
an architectural decision this phase needs to fix.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Secret inventory; env var handling by environment; two-mechanism build-time verification (import-boundary CI rule plus bundle content scan); rotation triggers. |
