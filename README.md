# SmartPOS X

**The Complete Mobile First Business Management Platform.**

Run an entire small business from an Android phone — and keep selling when the internet does not.

---

## Status

**Phase 18 — Implementation, Sprint 01.** All 17 design phases are complete and reviewed
(see [docs/README.md](docs/README.md) for the full phase map). Sprint 01
([docs/17-sprints/sprint-01.md](docs/17-sprints/sprint-01.md)) is in progress: repository scaffold
and Supabase Auth wiring. `apps/web` builds; `apps/mobile` is not yet scaffolded — see
[apps/mobile/README.md](apps/mobile/README.md) for why and what's needed.

## Documentation

All planning, design and decisions live in [docs/](docs/) — the single source of truth. Code
follows documentation, never the reverse.

Start with:

1. [Documentation index](docs/README.md) — the phase map and how to navigate
2. [Project Vision](docs/01-vision/project-vision.md) — what we are building and why
3. [Scope & Release Slices](docs/01-vision/scope-and-release-slices.md) — what ships when
4. [Milestones](docs/16-milestones/milestones.md) and [Sprints](docs/17-sprints/README.md) — what's being built right now

## Getting started (development)

```bash
pnpm install
cp apps/web/.env.example apps/web/.env.local   # then fill in a real Supabase project's values
pnpm --filter @smart-pos/web dev
```

`apps/web` needs a real Supabase project (free tier) to run against anything beyond `pnpm build`
and the unit tests — see [apps/web/.env.example](apps/web/.env.example) and
[supabase/sql/](supabase/sql/) for the SQL to apply to it.

## Technology

| Layer | Choice |
| --- | --- |
| Mobile | Flutter · Material 3 · Riverpod · Go Router · Drift (SQLite) |
| Backend | Next.js (App Router) · TypeScript · Prisma · Zod |
| Database | PostgreSQL |
| Platform | Supabase — authentication, storage, realtime |
| Delivery | GitHub · GitHub Actions |

Rationale for each choice is recorded in [docs/adr/](docs/adr/) as decisions are taken.

## Principles

1. Never stop selling — offline is the normal operating mode, not an error state
2. The sale is sacred — never lost, never duplicated, never silently altered
3. Tap count is a specification, not an aspiration
4. Correct beats convenient
5. Zero technical knowledge required
6. Works on the phone they already own
7. Boring, proven technology
8. Multi-tenant isolation is absolute

---

© SmartPOS X. Commercial software. All rights reserved.
