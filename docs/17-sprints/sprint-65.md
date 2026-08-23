# Sprint 65

> **Dates:** 2026-08-21 – 2026-08-21 (single-day, same cadence as every prior sprint)
> **Milestone:** M5 — First Real Shop (a dated exception to normal milestone ordering — decomposed
> ahead of M4's formal closure, by explicit founder direction)
> **Status:** Closed. No code change — this milestone has none.

## Goal

With every remaining M4 release-gate concern reduced to a purely founder-owned action (Sprints
62–64), there was no more unstarted engineering work of any kind left in this project. Asked
directly — hold, begin M5 prep now, or redirect to an audit of earlier phases — the founder chose
to begin M5 prep now, regardless of M4 not being formally "demonstrated" yet. This sprint records
that decision properly and does the actual prep work it authorizes.

## The decision, recorded precisely

`milestones.md`'s M5 row states its own Entry criteria plainly: "M4 demonstrated." That is not
literally true today — `release-checklist.md §2` still has two unresolved concerns. This project
has exactly one precedent for proceeding past an unmet entry criterion anyway:
[modules/README.md](../modules/README.md#rules) Rule 2's third exception, where M0's own physical-
print step stayed open (blocked on hardware) but the founder directed M1 to begin regardless — "a
one-off judgment call about *this specific* remaining item... not a reinterpretation of what 'M0
done' means for any future milestone."

This sprint's exception is recorded in the identical spirit, in the identical place a reader would
look for it (`milestones.md`, under M5's own table, not buried in a sprint doc alone): a dated note
naming the decision, naming that it was asked and answered plainly rather than assumed, and naming
explicitly what it does **not** change — M5's actual exit criterion (a real shop's real trading
day) still shouldn't happen before the RLS-application question (`check_rls_status.sql`, Sprint 62)
is confirmed. Prep and recruitment groundwork are safe to start now regardless; putting real
customer and sale data through the system for the first time is not something this exception waves
through.

## What was decomposed

`backlog.md §6` — M5's own item grain, for the first time. This is structurally different from
every milestone before it: `milestones.md`'s own Scope line for M5 is explicit — "No new product
scope." There is nothing to build. The decomposition instead breaks `pilot-plan.md`'s own
recruitment → pre-visit → day-one → follow-up sequence into seven trackable items, each founder-
owned, with a go/no-go gate (item 1, effectively M4's own remaining closure) named first since it's
the literal precondition for the actual pilot visit (item 4).

**One real, practical finding, made while doing this, not assumed away:** `success-metrics.md`'s
own §1 commits every listed metric to being "instrumentable from V1... If we cannot measure it with
the data the product already records, it is not a metric, it is a hope." That commitment holds in
the narrow sense — the underlying data genuinely exists for every pilot-target row — but not every
row is equally *visible* today. Cash reconciliation variance is already directly computed by
Trading Day's own close flow, live since Sprint 26 (M2). Sync success rate, duplicate sale rate, and
unresolved sync conflicts have no dedicated dashboard at all — M4's Reports scope (Sprint 37) only
ever covered the four core business reports (daily sales, top products, stock value, low stock),
never these engineering/pilot-health metrics. Reading them during the actual pilot means a direct
database query against `outbound_queue` status history, `sync_rejections`, and `audit_log`, not a
built screen. Named honestly in the decomposition itself, item 7, rather than discovered as a
surprise mid-pilot — and explicitly not treated as a defect to fix now: a dedicated dashboard for a
2–3-shop pilot the founder is personally present for is real, separately-scoped future work, not
something this sprint builds speculatively.

## Design decisions

1. **Record the exception in `milestones.md`, not only in this sprint doc.** A future reader
   checking why M5 work exists before M4 formally closed should find the answer at the milestone
   definition itself, the same place M0's own third exception lives — not have to discover it by
   reading sprint history.
2. **Decompose for trackability, not because M5 needs person-day estimates.** The `Estimate
   (person-days)` column every other milestone's table carries doesn't apply here — nothing is
   being built, so nothing is being estimated. The table uses an `Owner` column instead, and every
   row says "Founder," honestly reflecting that this milestone has no engineering content at all.
3. **Fix `backlog.md`'s own stale intro paragraph in the same pass, having noticed it directly.**
   It still claimed "M4 is still listed at module grain only" despite M4 having been fully
   decomposed since Sprint 43 (§5) — found by checking the paragraph against the document's own
   current section list while adding a new one, the same "check a claim against what's actually
   true" discipline this entire run of sprints has applied everywhere else.

## Definition of Done

- [x] `docs/16-milestones/milestones.md` — M5's Entry criteria exception recorded, dated, explicit
      about what it doesn't change.
- [x] `docs/17-sprints/backlog.md §6` (NEW) — M5 decomposed into 7 items, each founder-owned; old
      §6 (Ordering rule) renumbered to §7; the stale intro paragraph corrected.
- [x] `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md` updated in the
      same PR.
- [x] No code change — confirmed via `git status` showing only `docs/` files touched, consistent
      with M5's own "no new product scope."

## Demo script

**Local, run 2026-08-21:**

1. Read `modules/README.md` Rule 2's three existing exceptions in full before writing this sprint's
   own, to match their exact tone and rigor rather than improvise a new shape. ✅
2. Checked `backlog.md`'s intro paragraph against its own current section headings (§1–§6 as of this
   sprint) — confirmed the "M4 is still listed at module grain only" claim was stale, not current. ✅
3. Checked `success-metrics.md §1`'s "instrumentable from V1" claim against what M4's Reports scope
   actually built (Sprint 37) — confirmed only four of the pilot-target metrics have a dedicated
   built surface; the rest have the underlying data but no dashboard. ✅

**Not performed, and not this sprint's job to perform:** any actual recruitment, pre-visit, or
day-one action from `backlog.md §6`'s own item list. Those are real-world actions only the founder
can take — this sprint's job was making sure the plan for them is complete, trackable, and honestly
scoped, not doing them.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Worth naming: this is the first sprint in this entire session that produced zero lines of code and
was never going to — not because nothing was found (item 7's metric-visibility finding is real), but
because M5's own defined scope genuinely has no engineering content. Distinguishing "there's nothing
to build" from "we haven't found what to build yet" mattered here — the honest path was decomposing
what actually exists (a real-world sequence) rather than inventing engineering-shaped work to fill
the section the same way every prior milestone's own table was shaped.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-21 | Sprint 65: M5 decomposed into item grain (backlog.md §6) ahead of M4's formal closure, a dated exception recorded in milestones.md matching modules/README.md Rule 2's own M0→M1 precedent. M5 has zero engineering items, per its own "no new product scope." Found and named which pilot success-metrics are already visible via a built feature versus needing a manual database query. Fixed backlog.md's own stale intro paragraph. No code change. |
