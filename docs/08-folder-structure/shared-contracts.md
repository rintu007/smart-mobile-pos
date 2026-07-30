# Shared Contracts — Keeping Dart and TypeScript in Sync

> **Status:** 🔵 In review
> **Phase:** 08 — Folder Structure
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Chief Software Architect
> **Approved by:** _pending_

Dart and TypeScript share no type system — there is no way for `apps/mobile` to "import" a type
from `apps/web` directly. This document decides the mechanism that keeps them consistent anyway,
satisfying this phase's exit criterion that the mechanism is decided **and its generation step is
automated** — not left as a discipline of two engineers remembering to update both sides by hand.

---

## 1. The mechanism: OpenAPI as the single source of truth

[11-api's charter](../11-api/README.md) already commits to an `openapi.yaml` as "the machine-
readable specification, source for generated clients." This phase makes that concrete: the OpenAPI
document, authored and maintained in `packages/contracts/openapi.yaml`, is the **only** place an
API shape or error code is defined by hand. Both the TypeScript types used in `apps/web` and the
Dart models used in `apps/mobile` are **generated** from it — never hand-written in parallel, which
is exactly how contract drift happens.

```
packages/contracts/
├── openapi.yaml           # Hand-authored — the single source of truth
├── generate.ts            # Orchestrates both generation steps below
├── generated/
│   ├── typescript/        # Consumed by apps/web — NOT committed, regenerated at build/CI time
│   └── dart/               # Consumed by apps/mobile — NOT committed, regenerated at build/CI time
```

**Generated output is not committed to the repository.** It is regenerated on every build and in
CI, which means drift between the spec and either language's types is structurally impossible —
there is nothing checked in that could go stale. The accepted cost is that the Dart side needs
`build_runner` (or equivalent) wired into the Flutter build step, which is already normal practice
for a Flutter app using `freezed`/`json_serializable`, so this adds no new workflow the team isn't
already running.

## 2. Error codes are part of the same spec, not a second hand-maintained list

[11-api's `error-catalogue.md`](../11-api/README.md) documents error codes for humans; the
**machine-readable** list of the same codes lives as an enum within `openapi.yaml`'s components,
generated into a TypeScript union type and a Dart enum by the same step as every other type. A new
error code is added in exactly one place.

## 3. Generation tooling

- **TypeScript side:** an OpenAPI-to-TypeScript generator producing types and a typed fetch client
  (candidate: `openapi-typescript`, MIT-licensed and widely used for exactly this purpose —
  **verify current maintenance status at Phase 18 implementation time** before committing to it,
  per this project's dependency policy of not assuming a package's health from memory).
- **Dart side:** an OpenAPI-to-Dart generator producing Freezed-compatible models (candidate:
  an OpenAPI Generator Dart target, or a dedicated `openapi`-to-Dart pub package) — **also
  unverified in this research pass; confirm the best current option at Phase 18**, since Dart
  codegen tooling in this space has historically been less mature and more fragmented than the
  TypeScript equivalent, and naming one confidently now would risk the same overclaim
  [ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md) deliberately avoided for UUIDv7.
- **Orchestration:** `packages/contracts/generate.ts`, a single script running both generators,
  invoked via a root-level `pnpm generate:contracts` command **and** as a required CI step (Phase
  15) that fails the build if generation errors — not to check for drift (there's nothing committed
  to drift from) but to catch a spec that no longer generates valid code in either language.

## 4. What this buys, concretely

- A backend engineer changing a field name in the API updates `openapi.yaml`; both the TypeScript
  and Dart consumers get a compile error at their next build if they weren't updated to match —
  contract breakage is caught at build time, not discovered by a mobile app crashing in the field.
- A new API resource's types exist in both languages the moment its OpenAPI definition is written,
  before either the Route Handler or the Flutter screen consuming it is implemented.

## 5. What is explicitly not shared this way

Business logic (the `DR-NNN` rules) is implemented independently in each language where it must
run locally — the mobile client needs its own Dart implementation of, say, tax rounding
([money-and-tax.md](../07-database/money-and-tax.md)) for offline calculation, and the backend
needs its own TypeScript implementation for server-side verification (per
[11-api's charter](../11-api/README.md) rule that the server never trusts a client-supplied total).
**This is intentional duplication, not a gap** — the two implementations are kept consistent by
shared property-based test vectors (a set of input/expected-output pairs, itself defined once and
consumed by both languages' test suites), a Phase 14 concern, not a contract-generation one.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial mechanism: OpenAPI as source of truth, generated-not-committed output, orchestration script. Codegen tool names flagged for verification at Phase 18. |
