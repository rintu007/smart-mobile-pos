# Monorepo Layout

> **Status:** 🔵 In review
> **Phase:** 08 — Folder Structure
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Chief Software Architect
> **Approved by:** _pending_

Top-level structure for the monorepo already decided in
[ways-of-working.md §2](../00-governance/ways-of-working.md). This document fixes the actual
directory tree and the tooling that holds it together.

---

## 1. Top-level tree

```
smart-pos/
├── apps/
│   ├── mobile/              # Flutter application (Android-first, per project-vision.md)
│   └── web/                 # Next.js — mobile API + web admin (V2+) + QR storefront (V3+)
├── packages/
│   └── contracts/           # OpenAPI spec + generated TS/Dart types — see shared-contracts.md
├── docs/                    # This documentation set — the single source of truth
├── .github/
│   └── workflows/           # CI/CD — detailed in Phase 15
├── package.json             # Root workspace manifest (pnpm workspaces)
├── pnpm-workspace.yaml
└── README.md
```

Nothing else lives at the root. A file that doesn't obviously belong in `apps/`, `packages/`, or
`docs/` is a sign a decision hasn't been made yet, not an invitation to create a new top-level
folder without one.

## 2. Workspace tooling

**JavaScript/TypeScript side: `pnpm` workspaces.** Chosen over plain `npm` workspaces for its
stricter dependency resolution (no phantom dependencies — a package can only import what it
actually declares) and disk-efficient content-addressable store; chosen over `npm`/`yarn` because
both are free, permissively licensed, and `pnpm` is now the more commonly recommended default for
new TypeScript monorepos of this size. **No Turborepo or Nx layered on top for V1** — with one web
app and one small shared package, build-orchestration tooling would be solving a problem this
project doesn't have yet. Revisit only if build/CI time becomes a measured pain point, per
[project-vision.md §8](../01-vision/project-vision.md) Principle 7 (boring, proven technology).

**Dart/Flutter side: a single Flutter package, not a multi-package Dart workspace.** `apps/mobile`
is one Flutter application; internal separation is achieved through **folders**
([mobile-structure.md](mobile-structure.md)'s feature-first layout), not through splitting into
several published Dart packages coordinated by Melos. Multi-package Dart workspaces solve a
problem — enforcing hard boundaries between large, independently-versioned components — that a
single V1 mobile app does not yet have. Revisit if a genuine need for an independently-versioned
internal package emerges (unlikely before V4).

## 3. `packages/contracts`

The one shared package, holding the OpenAPI specification and its generated TypeScript and Dart
output — full detail in [shared-contracts.md](shared-contracts.md). It has no business logic; it
exists solely so both `apps/mobile` and `apps/web` depend on **one** definition of the API shape,
never on each other.

## 4. Why not a shared `packages/ui` or `packages/utils`?

Deliberately absent, per this phase's own rule against dumping-ground folders. Mobile and web use
different UI toolkits entirely (Flutter widgets vs. React/Next.js components) — there is no shared
UI code to house. Utilities live with the feature or app that owns them; a genuine cross-cutting
utility used identically by both `apps/mobile` and `apps/web` essentially cannot exist in this stack
(one is Dart, one is TypeScript), so the usual justification for a shared utils package doesn't
apply here at all.

## 5. What each app contains, at a glance

Full detail in their own documents — this is the map, not the territory:

| App | Structure document |
| --- | --- |
| `apps/mobile` | [mobile-structure.md](mobile-structure.md) |
| `apps/web` | [backend-structure.md](backend-structure.md) |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial monorepo layout: pnpm workspaces for TS side, single-package Flutter app, one shared contracts package. |
