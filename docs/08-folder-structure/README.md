# Phase 08 — Folder Structure

> **Status:** 🔵 In review — all 6 deliverables drafted
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Chief Software Architect

## Charter

| | |
| --- | --- |
| **Objective** | Define the physical code organisation for the monorepo, mobile app and backend, such that a file's correct location is never a matter of opinion. |
| **Inputs** | Phase 07 (🔵 In review). |

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`monorepo-layout.md`](monorepo-layout.md) | pnpm workspaces (TS), single-package Flutter app, one shared contracts package | 🔵 In review |
| [`mobile-structure.md`](mobile-structure.md) | 11 feature folders, 3-layer per-feature anatomy, module-to-folder mapping | 🔵 In review |
| [`backend-structure.md`](backend-structure.md) | Route Handler → Service → Repository → Prisma layering, 8-module mapping | 🔵 In review |
| [`shared-contracts.md`](shared-contracts.md) | OpenAPI as source of truth, generated-not-committed types, both codegen tools flagged for Phase 18 verification | 🔵 In review |
| [`naming-conventions.md`](naming-conventions.md) | Dart, TypeScript, PostgreSQL, API route conventions | 🔵 In review |
| [`layering-rules.md`](layering-rules.md) | Import rules for both apps + CI enforcement mechanism per side | 🔵 In review |

## Exit criteria

- [x] A new engineer can place any new file correctly without asking — every layer's placement rule
      is a table, not prose to interpret.
- [x] Layering rules are enforced by lint configuration, not by review vigilance —
      `dependency-cruiser` (TypeScript) and a CI import-scanning script (Dart, pending a dedicated
      package's verification at Phase 18) — [layering-rules.md §3](layering-rules.md#3-enforcement-mechanism).
- [x] Adding a new module requires no change to any existing module's files — true without
      qualification for the backend (Next.js file-based routing); true for mobile in the sense that
      matters (features never touch each other's files), with one narrow, explicitly stated
      exception at the app-shell composition root.
- [x] The Dart/TypeScript contract sharing mechanism is decided — OpenAPI as sole source of truth,
      generation automated via `packages/contracts/generate.ts` and wired into CI (Phase 15).

All four exit criteria are met at the design level; the only unresolved items are the specific
codegen/lint package names for Dart, deliberately left unnamed pending Phase 18 verification rather
than confidently naming tooling whose current maintenance status wasn't checked in this research
pass.

## Rules

- **Feature-first, not layer-first.** `features/pos/` containing its own data, domain and
  presentation beats a global `models/` directory. Layer-first structures force every change to
  touch four distant folders.
- **Dependencies point inward.** Presentation → Domain ← Data. Domain imports nothing from the
  other two, and no third-party type appears in domain code.
- **No shared "utils" or "helpers" dumping ground.** Such folders become an unowned, untested,
  circular-dependency-generating pile. Utilities live with the feature that owns them, or in a
  named, documented package.
