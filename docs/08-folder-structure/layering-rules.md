# Layering Rules

> **Status:** 🔵 In review
> **Phase:** 08 — Folder Structure
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Chief Software Architect
> **Approved by:** _pending_

What may import what, and — per this phase's exit criterion — **how it's enforced by tooling, not
review vigilance.** A rule that depends on a reviewer remembering it decays the first time that
reviewer is busy.

---

## 1. Mobile (`apps/mobile`) — within a feature

```
presentation  →  domain  ←  data
```

| Layer | May import | May NOT import |
| --- | --- | --- |
| `domain/` | Other files within the same feature's `domain/`; domain-safe `core/` primitives (`core/money`, `core/errors`) | `package:flutter/*`, `package:dio/*`, `package:drift/*`, `package:riverpod/*`, anything from `data/` or `presentation/` — domain is pure Dart, framework-free |
| `data/` | Its own feature's `domain/` (to implement its repository interfaces); `core/network`, `core/database`; third-party packages (Dio, Drift) | Another feature's `data/` or `domain/` directly |
| `presentation/` | Its own feature's `domain/`; Flutter, Riverpod, Go Router; `core/` UI primitives | `data/` directly — a screen depends on a domain-defined repository *interface*, wired to its concrete `data/` implementation via a Riverpod provider, never imported directly |

**Cross-feature rule:** `features/pos` never imports anything from `features/inventory` (or any
other feature) directly. If POS needs inventory data, it depends on a domain-level interface that
`core/` or the consuming feature declares, with the actual cross-feature data flow happening through
the API/sync layer, not an in-process import. This is what makes "adding a new module requires no
change to any existing module's files" true in practice — features genuinely don't reference each
other's internals.

**`core/` rule:** any layer, in any feature, may import from `core/`. `core/` must never import
from `features/*` — it is the dependency floor, nothing sits "beneath" it.

## 2. Backend (`apps/web`) — within a module

```
route handler (app/api/v1/*)  →  service  →  repository  →  Prisma
```

| Layer | May import | May NOT import |
| --- | --- | --- |
| Route Handler | Its module's `service.ts`, its module's `schema.ts` (Zod) | Prisma directly, another module's `service.ts`/`repository.ts` |
| `service.ts` | Its own module's `repository.ts`; `core/errors`; other modules' `service.ts` (this is the sanctioned cross-module path) | Next.js `Request`/`Response` types, another module's `repository.ts` directly |
| `repository.ts` | Prisma client (`core/db`) | Another module's tables, any business logic (an `if` deciding *what* to do, not just *how* to fetch) |

**Cross-module rule:** `modules/sales/service.ts` may call `modules/inventory/service.ts` (e.g. to
record a stock movement when a sale completes) — service-to-service is the one sanctioned
cross-module path, mirroring how the mobile side allows `core/`-mediated cross-feature flow but
never direct data-layer reach-through.

## 3. Enforcement mechanism

**TypeScript side: `dependency-cruiser`.** A mature, widely-used tool built specifically for
validating and enforcing module dependency graphs against a declared rule set, run as a CI check
(Phase 15) that fails the build on any forbidden import — not a lint warning a reviewer can miss,
a build failure they cannot merge past.

**Dart side: a CI script, not a dedicated lint package.** Rather than name a specific Dart
architecture-linting package with unverified current maintenance status (the same caution
[ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md) applied to UUIDv7 tooling and
[shared-contracts.md](shared-contracts.md) applied to Dart OpenAPI codegen), the enforcement
mechanism specified now is a small, dependency-free script — run in CI — that parses each Dart
file's `import` statements and fails the build if a `domain/` file imports a forbidden package
(`flutter`, `dio`, `drift`, `riverpod`) or a `presentation/` file imports another feature's `data/`.
This is boring, has zero new dependencies, and is trivially reliable. **If a dedicated Dart import-
linting package is confirmed well-maintained at Phase 18 implementation time, it may replace the
script — the rule set stays identical either way; only the enforcement mechanism would change.**

## 4. What "enforced by tooling" does not mean

It does not mean code review stops checking architecture — a CI gate catches an import violation
after the fact; a reviewer catching a design that technically has no forbidden import but still
smells like a layering violation (e.g. a `data/` class that's grown enough logic it should really
be in `domain/`) is still valuable and not replaced by tooling. The tooling's job is to make the
**bright-line** rules unmissable; judgment on everything softer than a bright line remains a human
job.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial layering rules for both apps, with a CI-enforced mechanism for each — `dependency-cruiser` (TS) and a custom script (Dart, pending confirmation of dedicated tooling at Phase 18). |
