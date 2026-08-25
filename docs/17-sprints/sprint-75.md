# Sprint 75

> **Dates:** 2026-08-26 (single-day)
> **Milestone:** none — a documentation-only staleness audit, not milestone work
> **Status:** Closed. No code change.

## Goal

Following Sprint 74's own precedent, this sprint applied the same staleness-check discipline to a
different category: Phase 12 (Security) documents that hadn't been touched since they were first
written (2026-07-30/31), before nearly all implementation happened. Starting from
`input-validation.md`, one specific claim — that mobile validation uses "Dart types generated from
`openapi.yaml`" — led to a much larger finding than expected.

## What was found

**The most significant finding of this entire run of sprints: the OpenAPI-driven contract-generation
mechanism `shared-contracts.md` designs as the actual way `apps/web` and `apps/mobile` stay
type-consistent was fully designed at Phase 08 and never built, at all, across 74+ sprints and
roughly 35 real API endpoints.** Checked directly rather than assumed from the design doc's own
confident tone:

- `packages/contracts/` contains only a stub `package.json` (with a `generate:ts` script that has
  apparently never been run against real output — it targets `docs/11-api/openapi.yaml`, not
  `packages/contracts/openapi.yaml` as `shared-contracts.md §1` itself specifies) and `node_modules`.
  No `openapi.yaml` inside the package, no orchestrator script, no `generated/` directory, no Dart
  generation of any kind — not even a chosen tool, despite the original document flagging tool
  selection as something to confirm "at Phase 18 implementation time," which has now been underway
  for the entire project's history.
- No `generate:contracts` script exists at the workspace root. No CI job generates or checks
  anything. `apps/web/package.json` doesn't list `@smart-pos/contracts` as a dependency. Nothing in
  `apps/web/src` or `apps/mobile/lib` imports from it — confirmed by grep, zero hits either way.
- `docs/11-api/openapi.yaml` — the file this whole mechanism would be authored against — was itself
  last touched in Sprint 01 (`git log`-confirmed) and documents 12 paths against roughly 35 real
  routes that exist today. It has not described the real API's actual shape for the overwhelming
  majority of this project's history.
- **This was never a documented pivot.** `implementation-log.md` mentions `packages/contracts`
  exactly once, in Sprint 01's own scaffold entry, and never again. No sprint doc, ADR, or Change Log
  entry anywhere states "we decided not to build OpenAPI codegen; here's what we do instead." It was
  simply never revisited once Phase 08 finished — the same class of silent abandonment Sprint 74
  found in `authentication/specification.md`, here applied to a foundational cross-cutting mechanism
  rather than a single module, and larger in consequence.

**What actually happened instead, and has genuinely worked for 74+ sprints:** every server module
hand-writes its own Zod schema; the mobile client hand-writes its own Dio-based API client code and
Freezed/Drift models. Consistency between the two is kept by this project's own established
cross-referencing discipline — the same "matches schema-server.md's own documented shape exactly"
pattern that appears throughout dozens of sprint docs and module specs — applied informally between
the two client implementations, never named as the actual mechanism in place of the designed one.

**Three other documents echoed the same false-as-fact framing, corrected in the same pass:**
`input-validation.md §1` (mobile validation "via generated Dart types" — corrected to name the real
mechanism, the practical guarantee unchanged) and §4 (claimed drift was "structurally" prevented —
corrected to state plainly that this risk is real and currently open, not closed); `mobile-structure.md`'s
folder-tree comment (`core/network/` "from packages/contracts" — corrected, confirmed by direct
inspection that only hand-written files exist there); `monorepo-layout.md §3` (reworded from a bare
factual claim to "designed"). A fourth, smaller and unrelated finding in the same document
(`input-validation.md §3`'s claim of a CI lint rule banning raw SQL) was checked and found equally
false — no such rule exists in `eslint.config.mjs` — the same "designed, never built" status this
project's own Dart import-boundary lint rule already admits for itself elsewhere.

## Design decisions

1. **Correct the record; do not build the designed mechanism now.** Building real OpenAPI-codegen
   at this point would mean: writing an accurate `openapi.yaml` for ~35 endpoints from scratch (the
   existing one describes barely a third of that, and none accurately); choosing and wiring a Dart
   codegen tool that was never even evaluated; and migrating ~15+ modules' already-working,
   already-tested, already-live-verified hand-written Zod schemas and Dart models onto generated
   equivalents — a large, invasive, high-risk refactor of working production code, for a benefit
   (structural drift prevention) this project has not actually suffered from in 74 sprints of the
   alternative. This is the same "premature generality" judgment this project has made before
   (Sprint 61's Play Console reasoning is the closest precedent) — building infrastructure ahead of
   a genuine, demonstrated need, rather than because a design document once specified it.
2. **Name the real, accepted risk explicitly rather than let the correction imply the risk is also
   closed.** The hand-written approach is not equivalent to generated types in one specific way:
   nothing today would catch a client/server type drift automatically the way generated code would.
   This project's own dense cross-referencing discipline has caught such drift *after the fact*
   dozens of times this session (that is largely what "Sprint N found and corrected..." findings
   *are*) — a real, working safety net, but a manual, retrospective one, not the structural, built-in
   guarantee `shared-contracts.md` originally promised. Stated as an accepted, informed risk now,
   not a hidden one.
3. **Treat this as formally accepting the alternative, not merely noting a gap.** `shared-contracts.md §0`
   doesn't just say "this wasn't built" — it explains why building it now is the wrong call, which
   functions as an actual (if informal) architecture decision, made explicitly here rather than left
   to be silently re-discovered and re-argued in a future sprint. If a second full client is ever
   added, or if a real client/server contract-drift bug is ever actually found in production, that's
   the concrete trigger for revisiting this decision — named, not left implicit.
4. **Correct every document making the false claim as fact, leave appropriately-hedged design
   documents alone.** `layering-rules.md`, `repository-setup.md`, and `docs/11-api/README.md` all
   reference this mechanism too, but each already frames it as a design decision or an unverified/
   flagged-for-later item, not as an operating fact — left untouched rather than over-corrected.

## Definition of Done

- [x] `docs/08-folder-structure/shared-contracts.md` — new §0, the primary correction, naming what
      was checked, what actually happens instead, and why this pass corrects rather than builds.
- [x] `docs/12-security/input-validation.md` — §1, §3, and §4 all corrected.
- [x] `docs/08-folder-structure/mobile-structure.md` — folder-tree comment corrected.
- [x] `docs/08-folder-structure/monorepo-layout.md §3` — reworded to "designed," not fact.
- [x] Every claim verified against real code/git history before being written: `packages/contracts/`'s
      actual contents, `apps/web/package.json`'s dependencies, a grep for any import of
      `@smart-pos/contracts` anywhere in either app, `git log` on `docs/11-api/openapi.yaml`, a count
      of real API routes vs. `openapi.yaml`'s documented paths, and a direct check of
      `eslint.config.mjs` for the claimed raw-SQL lint rule.
- [x] `git status` confirms only `docs/` files touched — no code, matching this sprint's own stated
      documentation-only scope.
- [x] `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md` updated in the
      same PR.

## Demo script

**Local, run 2026-08-26:**

1. `ls packages/contracts/` — confirmed only `package.json` and `node_modules`, no `openapi.yaml`,
   no `generated/`. ✅
2. `grep -rn "@smart-pos/contracts" apps/web/src apps/mobile/lib` — zero hits in either direction. ✅
3. `git log --oneline -- docs/11-api/openapi.yaml` — one commit, Sprint 01. ✅
4. Counted real routes (`find apps/web/app/api/v1 -name route.ts`, ~35) against `openapi.yaml`'s own
   path count (12). ✅
5. `grep queryRawUnsafe apps/web/eslint.config.mjs` — no match, confirming §3's separate claim was
   also false. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) — this one likely warrants an entry, unlike
most of this session's documentation corrections. Worth stating plainly: this is the largest gap
this entire run of staleness audits has found, precisely because it was never checked before. Every
prior audit this session ran (Sprints 69, 74, and today's own starting point) worked from a
suspicious *phrase* — "not yet built," "not implemented" — that a document itself flagged as a
known gap, then checked whether the flag was still accurate. This finding didn't start that way:
`shared-contracts.md` and `input-validation.md` both stated their claims with total confidence, no
hedge, no "not yet" — the kind of sentence a staleness grep for uncertainty-language would never
catch, because the sentence itself expressed no uncertainty. It was only checking one specific,
concrete claim ("Dart types generated from openapi.yaml") against the actual filesystem that
surfaced it. The lesson: a document's own confidence is not evidence of currency, and the highest-
value audits are the ones that pick a specific, falsifiable claim and check it directly, rather than
pattern-matching on words that only sometimes signal staleness.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-26 | Sprint 75: found the OpenAPI-driven client/server contract-generation mechanism `shared-contracts.md` designs was never built across 74+ sprints and ~35 real API endpoints — `packages/contracts/` holds only a stub, `docs/11-api/openapi.yaml` has been stale since Sprint 01, and the gap was never once documented as a decision. Named the real mechanism actually in use (hand-written Zod/Dart, kept consistent by this project's own cross-referencing discipline) and made the explicit call not to build the designed mechanism now, given the scale of already-working production code it would mean migrating. Corrected the same false claim in `input-validation.md` (§1, §4, plus an unrelated §3 finding — no CI lint rule bans raw SQL either), `mobile-structure.md`, and `monorepo-layout.md`. No code change. |
