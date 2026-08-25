# Shared Contracts — Keeping Dart and TypeScript in Sync

> **Status:** 🔵 In review
> **Phase:** 08 — Folder Structure
> **Version:** 0.2.0
> **Last updated:** 2026-08-26
> **Owner:** Chief Software Architect
> **Approved by:** _pending_

Dart and TypeScript share no type system — there is no way for `apps/mobile` to "import" a type
from `apps/web` directly. This document decides the mechanism that keeps them consistent anyway,
satisfying this phase's exit criterion that the mechanism is decided **and its generation step is
automated** — not left as a discipline of two engineers remembering to update both sides by hand.

---

## 0. Correction (2026-08-26) — this mechanism was fully designed, never implemented

**This is a real, load-bearing finding, not a small drift.** §§1–4 below describe a real design,
correctly decided at Phase 08 and never wrong *as a design* — but 74+ sprints of implementation
since (Sprint 01 through the present) never built it. Checked directly, not assumed:

- `packages/contracts/` contains only a `package.json` (with a `generate:ts` script that has never
  been run in anger — its own `openapi-typescript` target points at `docs/11-api/openapi.yaml`, not
  `packages/contracts/openapi.yaml` as this document's own §1 specifies) and `node_modules`. No
  `openapi.yaml` inside `packages/contracts/` itself, no `generate.ts` orchestrator, no `generated/`
  directory of any kind, no Dart generation of any kind — not even a chosen tool, despite this
  document's own §3 flagging tool selection as something to "confirm... at Phase 18," which has now
  been underway for 74+ sprints.
- The root `package.json` has no `generate:contracts` script. No CI job generates or checks
  contracts. `apps/web/package.json` doesn't even list `@smart-pos/contracts` as a dependency, and
  neither `apps/web/src` nor `apps/mobile/lib` imports from it anywhere (`grep`-confirmed).
- `docs/11-api/openapi.yaml` — the document this whole mechanism is supposed to be authored
  against — was itself last touched in Sprint 01 (`git log`-confirmed) and documents 12 paths,
  against roughly 35 real routes that exist in `apps/web/src/app/api/v1/` today. It has not
  described the real API's actual shape for the overwhelming majority of this project's history.

**What actually happened instead, and has worked for 74+ sprints:** every module hand-writes its
own Zod schema (`modules/<name>/schema.ts`, server-side) and the mobile client hand-writes its own
Dio-based API client code (`core/network/*.dart`) and Freezed/Drift models — matching, not
generating from, each other. Consistency between the two is kept by this project's own established
cross-referencing discipline, not automated codegen: sprint docs and module specs routinely state
things like "matches schema-server.md's own documented column exactly" or "the same shape the server
already returns" as an explicit, checked claim, the same discipline this entire run of sprints
(Sprints 50–61, 66–75) has repeatedly used to catch drift *between documentation and code* — applied
here, informally, *between the two client implementations themselves*, sprint over sprint, without
ever being named as the actual mechanism in place of the one this document specifies.

**This was never a documented pivot — no sprint doc, ADR, or Change Log entry anywhere in this
project ever states "we are not building OpenAPI codegen, here is what we do instead."** It reads as
a decision that was simply never revisited once Phase 08 finished, the same class of silent
abandonment Sprint 74 already found once in `authentication/specification.md`, here applied to a
foundational cross-cutting mechanism rather than a single module. Not fixed in this pass — see the
Retrospective in [sprint-75.md](../../17-sprints/sprint-75.md) for why building the designed
mechanism now, 74 sprints and roughly 35 endpoints into the project, is a much bigger and more
consequential decision than correcting the record about it.

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
| 0.2.0 | 2026-08-26 | Sprint 75 (security-docs staleness audit, extended to Phase 08): found this entire mechanism was designed and never built, unrevisited for 74+ sprints — `packages/contracts/` holds only a stub `package.json`, no `openapi.yaml`, no orchestrator, no Dart generation, no CI wiring; `docs/11-api/openapi.yaml` itself has been stale since Sprint 01, documenting 12 of roughly 35 real routes. Added §0 naming what actually happened instead (hand-written Zod/Dart, kept consistent by this project's own established cross-referencing discipline) and why this pass corrects the record rather than builds the designed mechanism now. |
