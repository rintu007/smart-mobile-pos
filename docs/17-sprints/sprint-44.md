# Sprint 44

> **Dates:** 2026-08-19 – 2026-08-19 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting closeout, not a
> numbered backlog item — a direct consequence of item 8's own findings)
> **Status:** Closed — documentation-correctness and honest status assessment only, no code changes.

## Goal

With M4 backlog items 1–8 done, check the milestone's own actual exit criterion —
[release-checklist.md §2](../14-testing/release-checklist.md#2-pilot-ready-checklist), the
pilot-ready gate [milestones.md — M4](../16-milestones/milestones.md#m4--reports-settings-and-release-readiness)
points to — against what Sprints 40–43 actually found and built, rather than assume the checklist's
own wording still matches reality. This is not a pre-planned backlog item; it is the direct,
necessary consequence of Sprint 43's own findings (a stale table count, a stale "all 10 scenarios"
claim, and two unresolved OWASP findings) colliding with a document whose entire purpose is to be
the literal release gate.

## What was found

1. **`release-checklist.md §2`'s cross-tenant-isolation row still said "all 22 tables plus the
   Realtime extension"** — stale since Sprint 40 (the real count is 19; the Realtime extension is
   named-and-deferred, not built). As worded, this row could never be honestly checked.
2. **Its failure-scenario row still said "all 10 offline failure scenarios passing"** — stale since
   Sprint 41's `test-plan.md §3` venue reclassification found only 1 of the 10 named scenarios is
   actually a server-testable, automatable case. Checked further this sprint: of the other 9,
   **zero have any verification on record at all, automated or manual** — grepped every sprint doc
   and the implementation log; the closest match, Sprint 16's airplane-mode end-to-end proof, verifies
   general offline-sync recovery, not the specific provoked scenarios (app killed mid-sync, device
   rebooted with a full queue, a token expired mid-queue, a +36-hour clock skew, etc.). This is a
   real, material pre-pilot risk: a real shop's Cashier will eventually have their phone die
   mid-shift or reboot with a full queue, and this project currently has no verified proof of what
   happens when that occurs, despite Phase 13's entire charter being written specifically to catch
   this class of failure.
3. **The OWASP row said "reviewed against the actual release build," full stop** — technically
   satisfied by Sprint 43 having done the review, but Sprint 43's review found two unresolved
   findings with real production risk (RLS very likely inert; rate limiting entirely unimplemented).
   As originally worded, the box could be checked despite both remaining open, defeating the
   checklist's own §5 rule that any unresolved item blocks a pilot release.

## What was corrected

All three rows above, in `release-checklist.md` itself, plus an explicit **Status, as of
2026-08-19** column added to every row in §2 — not just the three that changed — so the checklist
states plainly, per row, whether it is actually satisfied today rather than leaving that inference to
the reader. The corrections make the gate **more honestly unsatisfied**, not easier to pass, per
§5's own no-partial-credit stance.

## The honest conclusion

**This product is not pilot-ready today.** Four of eight rows in §2 are unresolved:

| Row | Why unresolved |
| --- | --- |
| Nightly suite green | `nightly.yml` (Sprint 42) has never actually fired on its own schedule yet — verified locally only. |
| Server-testable failure scenarios | 9 of 10 named scenarios have zero verification of any kind (finding #2 above). |
| MTS-01/02/03 executed | Founder-blocked on printer/reference-device hardware (M4 item 9, already tracked). |
| OWASP review, no unresolved critical findings | RLS's likely-inert defence-in-depth layer and the absence of rate limiting, both from Sprint 43, remain open. |

Three of these four are **new information from this sprint's own correction pass**, not previously
tracked as open risks against this specific gate — only MTS execution was already known. Recorded
plainly rather than left for a future reader to infer from a checklist that, until today, could not
even be honestly evaluated because two of its own rows described capabilities that were never built.

## Capacity check

No estimate was carried in the backlog for this item, since it was not a planned backlog line — a
same-day, documentation-correctness pass triggered directly by Sprint 43's findings, the same
"found while doing the adjacent real work" shape every prior sprint in this run has produced at
least one of.

## Definition of Done

- [x] `release-checklist.md §2` — every row's actual status recorded honestly, two stale rows
      corrected to match what Sprints 40–43 actually built.
- [x] backlog.md, implementation-log, `docs/README.md` all updated with the honest conclusion, not
      just the mechanical corrections.
- [x] No code changes this sprint — verified nothing needed touching (`tsc`/`eslint`/`vitest`/build
      already confirmed clean at the end of Sprint 43, immediately prior).

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this surfaces a concrete process
change — not pre-judged here. Worth naming regardless: this is the fifth sprint in a row (40–44) in
this run to find a real gap between a design document's claim and the system's actual state, and the
first to look specifically at the *release gate itself* rather than the individual capabilities it
cites — finding that the gate document had quietly drifted out of sync with the very sprints whose
job was to satisfy it. A release checklist that isn't re-verified against reality is exactly as
unreliable as any other design document in this set, and had never been checked before today.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-19 | Sprint 44: `release-checklist.md §2` checked against Sprints 40–43's real results for the first time — two stale rows corrected, an explicit per-row status column added, and an honest conclusion recorded: this product is not pilot-ready today, with four unresolved rows, three newly surfaced by this pass. No code changes. |
