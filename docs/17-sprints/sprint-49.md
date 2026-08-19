# Sprint 49

> **Dates:** 2026-08-19 – 2026-08-19 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting closeout, not a
> numbered backlog item — the same shape Sprint 44 itself took)
> **Status:** Closed.

## Goal

`release-checklist.md §2` — M4's own actual exit criterion — was last checked against real results
in Sprint 44, before Sprints 45–48 closed four more of Sprint 43's OWASP findings (rate limiting,
customer erasure, mobile secure token storage, on-device database encryption). With every genuinely
unblocked engineering item on that list now built, this sprint re-checks the release gate itself
against what actually changed, rather than assuming Sprint 44's snapshot still holds — the same
document-vs-reality discipline this project applies to code, applied here to its own checklist.

No code changes this sprint — documentation correctness and an honest status recheck only, the same
shape Sprint 44 itself took.

## What changed, checked against the real, current state — not assumed

1. **The nightly suite has now genuinely fired on its own schedule, not just locally.** Sprint 44
   recorded `nightly.yml` as "has never actually run on its own schedule yet." Checked directly via
   `gh run list --workflow=nightly.yml`: a real `schedule`-triggered run completed successfully
   (2026-08-18T20:47:29Z), not a `workflow_dispatch` manual trigger. This row now genuinely flips
   from unresolved to satisfied — the first row in either sprint's pass to do so, rather than only
   ever getting corrected toward *more* honestly unsatisfied.
2. **The OWASP row's "rate limiting on sign-in is entirely unimplemented" wording is now stale and
   was corrected, not just left as an approximation.** Sprint 45 built rate limiting for every
   endpoint class actually reachable from this codebase (mutating/read/sync-push). What remains
   open is narrower and different in kind: sign-in specifically is architecturally unreachable from
   this codebase at all (a direct client-to-Supabase-Auth call, never touching an `apps/web` Route
   Handler), needing a Supabase-side platform configuration check this session cannot perform —
   not unbuilt code. The row is corrected to say exactly that rather than continue implying a
   blanket "rate limiting doesn't exist" gap that hasn't been true since Sprint 45.
3. **RLS is unchanged, and was re-confirmed as unchanged rather than silently assumed.** No sprint
   between 44 and 49 touched it (all five deliberately skipped it, per the founder-input-pending
   deferral first stated Sprint 43) — checked `supabase/sql/*.sql` for any new `FORCE ROW LEVEL
   SECURITY` statement and `apps/web/src` for any new `request.jwt.claims`/`SET LOCAL ROLE` call on
   the app's own Prisma connection; neither exists. Still the single most significant open item.
4. **The 9 unverified failure scenarios are unchanged, and were re-confirmed as unchanged rather
   than silently assumed.** No sprint since Sprint 41 (which first established this count) added
   any new automated or manual coverage for them — checked the sprint docs and implementation log
   for any intervening mention; none exists.
5. **The four other real gaps Sprint 43 named were never counted toward the OWASP row's
   "critical/high-severity" bar in the first place** — worth stating explicitly here, since three of
   them (mobile secure token storage, on-device database encryption, customer-erasure
   anonymisation) are now built anyway (Sprints 46–48), and the fourth (Android release signing) is
   founder-blocked, not a same-session engineering item. None of this changes which rows in §2
   block a pilot release; it's stated to keep the checklist's own reasoning legible, not to pad the
   "fixed" count.

## Capacity check

No estimate carried in the backlog — a documentation-reconciliation pass, the same shape and cost
as Sprint 44 itself.

## Risks

None — no code changed. The only risk this sprint addresses is a documentation-accuracy one: a
release-readiness checklist that understates recent real progress (the nightly suite) or overstates
a stale finding (blanket "rate limiting unimplemented") is itself a release-process risk, since a
future release decision would be made against inaccurate information either way.

## Definition of Done

- [x] `release-checklist.md §2` — nightly-suite row flipped to satisfied (verified via `gh run
      list`, not assumed); OWASP row's rate-limiting wording corrected to the narrower, accurate
      sign-in-specific gap; RLS and the 9 unverified failure scenarios re-confirmed unchanged;
      bottom-line summary updated from four to three unresolved rows.
- [x] backlog.md, implementation-log, `docs/README.md` updated in the same PR.

## Demo script

**Local, run 2026-08-19:**

1. `gh run list --workflow=nightly.yml --limit 10` — shows one `completed`/`success` run with
   trigger `schedule`, not `workflow_dispatch`. ✅
2. Grepped `supabase/sql/*.sql` for `FORCE ROW LEVEL SECURITY` and `apps/web/src` for
   `request.jwt.claims`/`SET LOCAL ROLE` — zero hits, confirming RLS's status is genuinely
   unchanged rather than assumed. ✅

No code changes; no `tsc`/`eslint`/`vitest`/`flutter analyze`/`flutter test` run needed — nothing in
either app's source changed.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this surfaces a concrete process
change — not pre-judged here. Worth naming regardless: this is the second time this project has
re-checked its own release checklist against reality rather than trusting a prior pass's snapshot
(Sprint 44 was the first) — and the second time was worth doing, since one row's real-world status
had genuinely changed (the nightly suite) and another's wording had gone stale in a way that
understated real progress (Sprint 45's rate limiting). A checklist that's only ever corrected
downward would itself become a source of drift over time; this pass corrected in both directions.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-19 | Sprint 49: release-checklist.md §2 re-checked against Sprints 45–48's real results. Nightly-suite row flips to satisfied (confirmed via `gh run list`, a real scheduled run passed). OWASP row's stale "rate limiting unimplemented" wording corrected to the narrower, accurate sign-in-specific architectural gap. RLS and the 9 unverified failure scenarios re-confirmed unchanged. Bottom line: still not pilot-ready today, now three unresolved rows instead of four. No code changes. |
