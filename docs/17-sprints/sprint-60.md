# Sprint 60

> **Dates:** 2026-08-21 – 2026-08-21 (single-day, same cadence as every prior sprint)
> **Milestone:** M2 — Full POS Loop (cross-cutting fix, not a numbered backlog item —
> documentation-accuracy only, no code change)
> **Status:** Closed. A real, previously-uncaveated gap between a milestone's exit criterion and
> its own declared closure, found by extending Sprint 58/59's discipline one level further.

## Goal

Sprints 58 and 59 checked whether specific findings had been correctly threaded into the actual
release gate that should track them, rather than assumed. This sprint asks the same question one
level up: does every milestone's own stated exit criterion actually match what was verified when
that milestone was declared closed? M4 gets this scrutiny by construction (`release-checklist.md`
exists specifically to check it, and has been re-checked six times this run of sprints). M0's exit
criterion was closed with an explicit caveat (Sprint 16). M1 and M3 have no physical-hardware
dependency to check. M2 had never been checked this way at all.

## What was found

`milestones.md`'s M2 row states: *"The full tap-count-audit.md budget is met on every Till
workflow, measured on the reference low-end device (device-matrix.md), **not estimated**."*
`backlog.md §3` declared M2 "fully closed, all 6 items done" at Sprint 30, with no caveat attached.

Checked directly: `tap-count-audit.md` (Phase 09, v0.1.0) is explicitly a design-time trace —
"every V1 workflow traced through route-map.md and navigation-model.md, tap by tap" — never a
physical measurement, and its own text never claims otherwise. The reference low-end device
`device-matrix.md` names has never been owned — this is not a new fact; it is the exact same,
already extensively-tracked blocker behind M4 item 9/MTS-01/MTS-03 (unchanged since Sprint 43). What
was missing was the connection between that already-known fact and M2's own exit-criteria text,
which explicitly demands something `tap-count-audit.md` was never meant to provide.

This project's own track record shows the right way to handle exactly this situation: M0's exit
criterion also required a real, physical action (print a receipt) that wasn't available at the time
of its own closure attempt — Sprint 16 named this plainly ("step 8 remains open, blocked on printer
hardware the founder confirmed they don't have yet") rather than declaring M0 closed without
qualification. M4's exit criterion is *never* declared satisfied while its own hardware-dependent
row remains open — it stays honestly "not pilot-ready" instead. M2 is the one milestone where this
discipline wasn't applied — its closure entry simply didn't engage with its own exit criterion's
text at all.

## Design decisions

1. **Correct this the same way Sprint 44 corrected `release-checklist.md`'s stale rows: name the
   gap, don't retract the closure.** M2's 6 backlog items genuinely are built — nothing about this
   finding suggests otherwise, and unbuilding a real correction into a rebuild would be exactly the
   overreaction this project's own "no partial credit, but no false alarms either" balance argues
   against. The fix is naming what M2's own exit-criteria text still requires, not undoing work.
2. **Correct in both `milestones.md` (the exit criterion's home) and `backlog.md` (the closure's
   home), matching the two-document pattern already established for M4's own Scope-line
   correction.** A one-sided fix would leave the same disconnect visible from the other document.
3. **Check M1 and M3 too, not just assume M2 is the only instance.** Neither has a
   physical-hardware-dependent exit criterion (M1: server-enforced role tests; M3: return/conflict
   behavior, both software-verifiable) — confirmed directly rather than left unchecked.
4. **Do not open a new backlog item or launch an M2-specific "verification sprint."** The
   underlying blocker (no reference device) is already tracked, already founder-blocked, already
   named in the same place (`device-matrix.md`/MTS rows) that will resolve it whenever the founder
   acquires the hardware — a redundant second tracking mechanism specific to M2 would fragment
   rather than clarify.

## Definition of Done

- [x] `docs/16-milestones/milestones.md` — dated correction note added under M2's row, matching the
      format already used for M4's own Sprint-16-era Scope-line correction.
- [x] `docs/17-sprints/backlog.md §3` — matching dated correction note added under M2's closure line.
- [x] Confirmed M1's and M3's exit criteria don't share this issue.
- [x] `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md` updated in the
      same PR.
- [x] No code change this sprint — verified via `git status` showing only `docs/` files touched.

## Demo script

**Local, run 2026-08-21:**

1. Read `tap-count-audit.md` in full — confirmed it self-describes as a trace against
   `route-map.md`/`navigation-model.md`, never a physical measurement claim. ✅
2. Read `milestones.md`'s M0/M1/M2/M3/M4 exit-criteria rows side by side — confirmed only M0, M2,
   and M4 have any real-world/hardware dependency, and only M2's closure lacked a caveat for it. ✅
3. Confirmed `device-matrix.md §3`'s reference-device finding is unchanged since Sprint 43 — the
   same fact, not a new one, simply not yet connected to M2's own exit criterion before this sprint. ✅

**Not performed, and not performable:** actually measuring `tap-count-audit.md`'s budget on a real
reference device. This remains exactly as founder-blocked as MTS-01/MTS-03 already are — this
sprint's job was making sure M2's own closure honestly reflects that, not resolving it.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Worth naming: Sprints 58, 59, and 60 are a matched set — each checks a different kind of "was this
actually threaded through correctly" question (a finding into its release gate; a claim into its
supporting evidence; a milestone's exit criterion into its own closure declaration). None of the
three found new engineering work. All three found real gaps in how this project's own extensive,
otherwise disciplined documentation connects to itself — a different failure mode from "the code
doesn't match the doc," worth tracking as its own category going forward: **accounting gaps**,
distinct from **correctness gaps**, checked by a different method (cross-document reconciliation,
not code-vs-doc comparison) and worth a dedicated pass the next time this project does a major
documentation sweep, not only when a "continue" prompt happens to land on one by chance.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-21 | Sprint 60: found `milestones.md`'s M2 exit criterion (a physical-reference-device measurement) was never actually satisfied, and M2's own Sprint 30 closure carried no caveat against this — unlike M0's and M4's honest treatment of an equivalent hardware-dependent exit criterion. Corrected `milestones.md` and `backlog.md §3` with a dated note; M1/M3 checked and confirmed not to share this issue. No code change. |
