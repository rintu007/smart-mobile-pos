# Phase 17 — Sprint Planning

> **Status:** 🔵 In review — all 5 deliverables drafted; Sprint 01 through Sprint 07 all closed
> **Version:** 0.9.0
> **Last updated:** 2026-08-02
> **Owner:** Product Manager / CTO

## Charter

| | |
| --- | --- |
| **Objective** | Break milestones into executable sprints, each delivering something complete under the Definition of Done. |
| **Inputs** | Phase 16 (🔵 In review, OD-06 resolved). |

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`sprint-cadence.md`](sprint-cadence.md) | 2-week sprints; every ceremony kept or dropped with its reason tied to the resolved solo/10–20hrs reality | 🔵 In review |
| [`sprint-template.md`](sprint-template.md) | Explicit capacity-check section; checkbox-based (not %-based) defect/doc reservation | 🔵 In review |
| [`backlog.md`](backlog.md) | M0 fully decomposed into 12 estimated, dependency-ordered items (20 person-days, item 12 added Sprint 06 planning) | 🔵 In review |
| [`sprint-01.md`](sprint-01.md) | Repository scaffold + Auth wiring — both items done, demoed on real infrastructure | 🟢 Done |
| [`sprint-02.md`](sprint-02.md) | `POST /api/v1/onboarding` (Company & Store Setup) — built and demoed live | 🟢 Done |
| [`sprint-03.md`](sprint-03.md) | Flutter SDK installed, `apps/mobile` scaffolded, local Drift database built (backlog.md item 4) | 🟢 Done |
| [`sprint-04.md`](sprint-04.md) | `POST /api/v1/products` (Products) — built and demoed live, a real `requireSession` bug found and fixed | 🟢 Done |
| [`sprint-05.md`](sprint-05.md) | `POST /api/v1/sales` (POS) — built and demoed live with server-side recompute; no new bug found | 🟢 Done |
| [`sprint-06.md`](sprint-06.md) | Mobile `/auth/login` — the first real Flutter screen, verified live against Supabase Auth | 🟢 Done |
| [`sprint-07.md`](sprint-07.md) | Mobile product creation (`/catalogue/add`) — local write path, verified against a real on-disk file | 🟢 Done |
| [`retrospective-log.md`](retrospective-log.md) | Sprint 01–07 retrospectives recorded: "verified locally" ≠ "CI-ready" ≠ "the endpoint/database works" ≠ "new tooling won't surprise you" ≠ "one proven function means the whole file is proven" ≠ "the demo device exists" ≠ "the demo process actually exited" | 🔵 In review |

## Exit criteria

- [x] Each sprint has **one** goal, stated in a single sentence — [sprint-template.md](sprint-template.md)'s
      Goal section, demonstrated concretely in [sprint-01.md](sprint-01.md).
- [x] Each sprint's output is demonstrable and meets the Definition of Done — [sprint-01.md](sprint-01.md)'s
      Demo script and its explicitly scoped-down DoD subset (never claiming boxes a 2-item slice
      can't actually satisfy).
- [x] No sprint mixes more than two modules — [sprint-01.md](sprint-01.md) scopes exactly one
      (Identity/Auth, plus the repository scaffold it depends on).
- [x] Every sprint reserves capacity for defects and documentation —
      [sprint-template.md](sprint-template.md)'s checkbox-based reservation, populated with concrete
      amounts (not left at a defaultable percentage) in [sprint-01.md](sprint-01.md).

All four exit criteria are met, demonstrated concretely rather than only specified abstractly —
Sprint 01 is a real, executable sprint plan, not just a template with no worked example. Per this
phase's own rule against batch-authoring future sprints, Sprint 02 onward are written when Sprint 01
actually closes, not pre-drafted here.

## Rules

- **One module at a time.** A module is complete before the next begins. This is the founding rule
  and sprint planning does not get to negotiate with it — **with the same M0 walking-skeleton
  exception named in [modules/README.md's Rule 2](../modules/README.md#rules)**, not a separate
  looser rule for sprints specifically: during M0, "one module" means M0 itself, since M0 is by
  design a cross-cutting slice through several Registry rows at once.
- Unfinished work does not silently roll forward. It is re-estimated and re-prioritised against
  everything else, because circumstances changed.
- Retrospectives change something concrete or they are cancelled. A retrospective that produces
  only sentiment is a meeting.
- Documentation is inside the sprint, never after it. "We will document it later" is how the single
  source of truth stops being true.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | All 5 deliverables drafted; Sprint 01 planned and ready for Phase 18 kickoff. |
| 0.2.0 | 2026-08-01 | Sprint 01 closed (both backlog items done, demoed live). |
| 0.3.0 | 2026-08-01 | Sprint 02 planned. Found and closed a real gap first: Authentication and Company & Store Setup had no module specifications despite Authentication already having live code, and Phase 11 had never specified the actual signup/onboarding endpoint. Also amended the "one module at a time" rule with the M0 walking-skeleton exception, matching [modules/README.md](../modules/README.md)'s own correction. |
| 0.4.0 | 2026-08-01 | Sprint 02 closed: built and demoed live against the real database, all 6 demo steps passed. Found and fixed a real row-ordering bug (`stores_created_by_fkey`) on first contact with live data. |
| 0.5.0 | 2026-08-01 | Sprint 03 planned and closed same-day: Flutter SDK installed (the founder-blocked item named since Sprint 01), `apps/mobile` scaffolded and reshaped, local Drift database built for backlog.md item 4 and verified via `flutter test`. Two real package-version findings (Riverpod 3.x vs. `riverpod_lint`, `sqlite3_flutter_libs` obsolescence). |
| 0.6.0 | 2026-08-01 | Sprint 04 planned and closed same-day: found and resolved a real spec gap (catalogue.md's full `POST /products` contract vs. backlog.md's M0-minimal scope) before writing code, built and demoed `POST /api/v1/products` live including a cross-tenant RLS proof. Found and fixed a real, three-sprints-latent `requireSession` bug. |
| 0.7.0 | 2026-08-02 | Sprint 05 planned and closed same-day: found and resolved two real spec gaps (sales.md's full contract vs. backlog.md's M0-minimal scope; WF-002's stock-ledger atomicity vs. the item 6/7 split) before writing code, built and demoed `POST /api/v1/sales` live with server-side recompute and a cross-tenant RLS proof. No new bug found — `requireSession`'s fix held on its second real caller. |
| 0.8.0 | 2026-08-02 | Sprint 06 planned and closed same-day: found and closed a real backlog gap (mobile sign-in was never decomposed, added as item 12), built and verified `/auth/login` — the mobile app's first real Flutter screen — live against Supabase Auth. Found and fixed a real pre-ship bug (an async `build()` causing a spurious loading flash) and two real environment gaps (disk full; no local device could run the actual UI), both logged honestly in retrospective-log.md. |
| 0.9.0 | 2026-08-02 | Sprint 07 planned and closed same-day: closed backlog item 5's remaining mobile scope, built and verified `/catalogue/add`'s local write path against a real on-disk file across a fresh connection. Found and fixed a real route-map.md gap and a real `Product` name collision; diagnosed a real memory-exhaustion issue (leftover Chrome processes from Sprint 06's demo) with the founder's help rather than guessing. |
