# Sprint 74

> **Dates:** 2026-08-26 (single-day)
> **Milestone:** none — a documentation-only staleness audit, not milestone work
> **Status:** Closed. No code change.

## Goal

With Sprint 69–73's own arc fully closed, a quick bounded scan for the same class of drift —
"not yet built" claims describing features that were actually built long ago and never corrected —
was run across every module spec, not just `schema-server.md`. It found real, significant hits on
the very first pass, worth pursuing properly rather than treated as a one-off Phase 07 concern.

## What was found

`grep -rn "[Nn]ot yet built" docs/modules/` surfaced six files. Four hits were genuine, real drift;
two (`products/specification.md`'s `/catalogue` list screen, and the same document's deferred
`PATCH`/`DELETE /products` endpoints) were checked and confirmed still accurate — no `/catalogue`
route exists anywhere in `apps/mobile/lib`, confirmed by direct grep before ruling them out.

**The most significant finding: `authentication/specification.md` had not been updated since Sprint
06 (2026-08-02) — 55+ sprints, unchanged — despite Sprint 23 (Roles & Permissions), Sprint 55
(device registration/revocation, server), and Sprint 56 (device registration/revocation, mobile)
each building exactly what this document kept describing as unbuilt across nearly every one of its
11 sections.** Confirmed against real code before writing any correction: `core/auth/session.ts`'s
`requireSession` genuinely runs all four evaluation-order steps including `devicesService.assertDeviceUsable`
against the `X-Device-Id` header (line 139); all three device routes (`POST /auth/register-device`,
`GET /devices`, `PATCH /devices/{id}/revoke`) exist and are wired with the exact permission gating
the original spec had only ever *designed*, never confirmed built. The one claim that *was* still
accurate, checked rather than assumed: no device-list/revocation UI screen exists anywhere in
`apps/mobile/lib` — the backend and the client-side registration/revocation-reaction logic are both
built, but there is genuinely no Owner-facing screen to browse or act on the device list. This is a
real, if ironic, gap: §0 of this exact document explicitly promises "every section... is checked
against what actually exists," a standard the document itself failed to hold for over 400 hours of
project time.

**Three smaller, related hits, each verified before correcting:**
- `docs/modules/README.md`'s own Authentication row echoed the same stale "device registration/
  revocation not yet built" claim in the module registry index.
- The same file's Roles & Permissions row claimed "any `devices` endpoint have no code to retrofit
  yet" — checked directly (`grep requirePermission` on the three device route files) and found both
  `GET /devices`/`PATCH /devices/{id}/revoke` do carry `requirePermission(["owner"])`, built the same
  sprint as the endpoints themselves.
- `sync-engine/specification.md`'s Sprint 36 entry called Reports "not yet built" — true when that
  sprint ran, but Reports shipped the very next sprint (37) and this historical note was never
  annotated to reflect it.
- `pos/specification.md §1` had a second, earlier stale claim distinct from the one Sprint 73 already
  fixed in this same document's later `sale_line_items` section — "no Trading Day precondition
  (Trading Day is its own M2-scope module, not yet built)" (built Sprint 26) and "no `device_id`...
  isn't built yet either" (never actually part of the real design at all, per Sprint 69's own
  `schema-server.md` correction — not merely delayed).

## Design decisions

1. **Correct in place, dated, with the evidence — never silently rewrite history.** Every fix
   preserves what the document originally said (via a "**Correction:**" callout) rather than editing
   the historical sentence away, matching this document set's own established convention throughout
   every prior dated correction this session has made.
2. **Verify against real code before writing any fix, the same discipline as every prior sprint in
   this arc.** Two claims from the initial `grep` hit list were checked and confirmed still true
   (the `/catalogue` list screen, deferred `PATCH`/`DELETE /products`) rather than corrected on the
   assumption that any "not yet built" hit must be stale — a document being old doesn't make every
   claim in it wrong.
3. **Distinguish "backend built, UI still missing" precisely rather than declare the whole module
   fixed.** `authentication/specification.md`'s single biggest risk in a hasty correction would have
   been overclaiming — swinging from "everything is unbuilt" to "everything is built" would have
   been just as wrong as the original staleness. The device-list/revocation screen gap is real and
   is named as such, distinctly from the now-corrected backend claims.
4. **Bounded scope, stated explicitly.** This was a targeted grep-and-verify pass across one
   specific phrase pattern ("not yet built"), not an exhaustive re-read of every module spec's every
   claim — the same deliberate boundary Sprint 69 drew for `schema-server.md`, applied here to a
   different document set.

## Definition of Done

- [x] `docs/modules/authentication/specification.md` — comprehensive correction across §§1–11 plus
      "What's honestly not done", version bumped 0.2.0 → 0.3.0.
- [x] `docs/modules/README.md` — Authentication, Roles & Permissions, and Trading Day rows corrected.
- [x] `docs/modules/sync-engine/specification.md` — Sprint 36 entry's Reports claim annotated.
- [x] `docs/modules/pos/specification.md` — a second stale claim (distinct from Sprint 73's fix)
      corrected, version bumped 0.10.3 → 0.10.4.
- [x] `git status` confirms only `docs/` files touched — no code, matching this sprint's own stated
      documentation-only scope.
- [x] `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md` updated in the
      same PR.

## Demo script

**Local, run 2026-08-26:**

1. `grep -rn "[Nn]ot yet built" docs/modules/` — the entire investigation's starting point, run
   before assuming any specific document needed attention. ✅
2. For each hit, checked the real current state directly before deciding whether to correct it:
   `grep` for a mobile `/catalogue` route (none — confirmed still accurate), read
   `core/auth/session.ts` directly to confirm all four evaluation-order steps are real, `grep
   requirePermission` on the three device route files to confirm their actual gating. ✅
3. Re-read the fully corrected `authentication/specification.md` end to end after editing, checking
   for any remaining internal inconsistency between corrected and uncorrected sections. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
The `authentication/specification.md` finding is worth sitting with: this is not a small, easily-
missed edge case the way some of Sprint 69's smaller drifts were — it's the single most foundational
module in the entire system, "not yet built" for over 400 hours of elapsed project time on features
that had shipped, been live-verified, and been in continuous production use the whole while. No
release-gate check, no OWASP review, no prior audit ever opened this specific file and read it
against the running system — every one of those checks looked at the *code's* correctness, never at
whether the one document a new reader would open first to understand Authentication was still
telling the truth. The lesson isn't "audit every module spec exhaustively" (a real risk of unbounded
work, deliberately not taken here) — it's that a cheap, five-minute grep for one suspicious phrase
pattern, run periodically across the whole doc set rather than only when a specific document is
already open for another reason, would have caught this in one sprint instead of fifty.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-26 | Sprint 74: a bounded grep-and-verify pass across every module spec's "not yet built" claims found `authentication/specification.md` unchanged since Sprint 06 (55+ sprints) despite Sprint 23/55/56 building nearly everything it still described as unbuilt — corrected comprehensively across all 11 sections, narrowed to the one genuinely remaining gap (the device-list/revocation UI screen). Also corrected three smaller, related hits: `modules/README.md`'s Authentication/Roles & Permissions/Trading Day rows, `sync-engine/specification.md`'s Sprint 36 Reports note, and a second stale claim in `pos/specification.md §1`. Two other hits checked and confirmed still accurate, not corrected. No code change. |
