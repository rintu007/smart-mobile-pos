# Sprint 59

> **Dates:** 2026-08-21 – 2026-08-21 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item — documentation-accuracy only, no code change)
> **Status:** Closed. Arguably the most consequential finding of this entire run of sprints — not
> because anything was built, but because of what it means for what's already live.

## Goal

Sprint 58 found that a known finding (Android release signing) had never been threaded into the
actual release gate. That raised an obvious follow-up question, applied here to the *other*
standing finding in the same category: RLS. Sprint 43 found RLS is "very likely inert" for all real
production traffic, reasoning from the assumption that the policies exist in production but are
merely owner-exempt. This sprint checks that assumption directly, the same way Sprint 58 checked
`cd-workflows.md §1`'s own blanket claim rather than trusting it.

## What was found

`cd-workflows.md §1` (corrected Sprint 55) claims "every numbered file from `001_` through `019_`
has, in practice, required a human to run it against the real Supabase SQL editor by hand after
merging — confirmed by `implementation-log.md`'s own repeated 'applied live' entries." This claim
was checked file-by-file against every introducing sprint doc and every `implementation-log.md`
entry, rather than trusted:

- **Confirmed, explicit "applied live" language on record:** `003`, `004`, `005`, `006`, `007`,
  `012`, `015` — 7 of 18 RLS files.
- **Ambiguous — no file-specific confirming sentence, but each introducing sprint's own live demo
  ran against real production Supabase with a passing cross-tenant RLS check for that table:**
  `010`, `011`, `013`, `014`, `016`.
- **No confirmation anywhere on record:** `017` and `018`
  (`sale_line_items`/`sale_payments`/`return_line_items` — Sprint 40's own fix for the two tables
  that had *zero* RLS enabled at all, described at the time as "the single most significant finding
  of this project so far") and `019` (`devices`, Sprint 55). This is direct documentary evidence, not
  inference: Sprint 40's own text explicitly distinguishes verification "against the real applied
  SQL locally" from "the shared production Supabase project," and never once claims the latter for
  these two files. Sprint 55's own demo script explicitly lists a real-Supabase smoke test as "not
  performed this sprint," judged less consequential than the coverage already in hand — a
  reasonable call at the time, but one that leaves this specific question open.

**Why this matters more than it might first appear:** Sprint 43's existing finding reasons that
"the application demonstrably works in production... is only consistent with the owner-exempt,
RLS-inert case." That reasoning doesn't hold once a second explanation is on the table. A table
whose RLS policy was simply never applied would look **identical** from the outside to a table whose
policy is present but owner-exempt — in both cases, the app's own service-layer `WHERE tenant_id =
...` scoping is doing all the real protective work, and nothing about normal application behavior
would reveal the difference. "It works" cannot be used as evidence for one explanation over the
other. Neither this session nor any prior sprint has ever checked `pg_class.relrowsecurity` (or
equivalent) against the real production database directly — the one check that would actually
settle this.

## Design decisions

1. **Correct the finding in place across all three documents that reference it, rather than adding
   a new document.** `owasp-checklist.md` (the primary finding), `cd-workflows.md §1` (the specific
   claim that turned out imprecise), and `release-checklist.md` (the release gate) all needed the
   same correction, the same discipline Sprint 58 already applied across the same three documents
   for a different finding.
2. **Frame this as a second, independent dimension of the existing RLS finding, not a separate,
   competing one.** Both ultimately ask "does RLS actually protect anything in production right
   now?" — Sprint 43's question (is FORCE set, is the role right) only becomes the relevant question
   *after* confirming the policies exist at all. Sequencing it this way, rather than listing two
   unordered concerns, tells the founder which question to answer first.
3. **Do not attempt to verify this by any indirect means.** There is no code-level proxy for "check
   the real production database's `pg_class.relrowsecurity`" — building one (e.g., an endpoint that
   reports this) would itself need to run in production to be useful, the same chicken-and-egg
   problem every other founder-blocked item in this project already has. Named and flagged instead.

## Definition of Done

- [x] `docs/12-security/owasp-checklist.md` — finding #1 (RLS) extended with the second, independent
      possibility, precisely scoped to the three files with no confirmation on record.
- [x] `docs/15-github-project/cd-workflows.md §1` — its own "confirmed by... 'applied live' entries"
      clause corrected to the actual, file-by-file breakdown.
- [x] `docs/14-testing/release-checklist.md` — OWASP row's RLS description extended; bottom line
      flags this as the single most action-critical item outstanding.
- [x] `backlog.md`, `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md`
      updated in the same PR.
- [x] No code change this sprint — verified via `git status` showing only `docs/` files touched.

## Demo script

**Local, run 2026-08-21:**

1. Grepped every occurrence of "applied live" across `implementation-log.md` and cross-referenced
   each against the SQL file it names — confirmed the phrase appears for `003`–`007`, `012`, `015`
   only. ✅
2. Read Sprint 40's and Sprint 55's own sprint docs in full for any language distinguishing local
   vs. real-production verification for `017`/`018`/`019` specifically — confirmed both sprints'
   own text already, explicitly, does not claim production application for these three files. ✅

**Not performed this sprint, and not performable by this session at all:** checking the real
production Supabase database directly. This is the entire point of the finding — it is a question
only the founder (or someone with real production database access) can answer, and this sprint's
job was to make sure that question is asked clearly and precisely, not to answer it.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Worth naming plainly: this sprint did not find a new engineering task. It found that a security
finding this project has treated as "known, just blocked" for 16 sprints (since Sprint 43) was
actually resting on an unverified assumption about production state — a different, more urgent
category than "blocked pending a decision." The standing lesson from Sprints 50–54/57/58 has been
"check a doc's claim against the code before trusting it." This sprint's lesson is a variant worth
naming separately: **check a doc's claim about production state against the actual production
record before trusting it, too** — code and documentation can both be checked from inside this
repository; production state cannot, and claims about it deserve correspondingly more scrutiny, not
less, precisely because they're the hardest to verify.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-21 | Sprint 59: checked `cd-workflows.md §1`'s claim that every RLS SQL file was eventually applied to production, file by file, and found no confirmation on record for `017`/`018`/`019` at all — a distinct, more severe possibility than `owasp-checklist.md`'s existing FORCE/role finding, since "the app works in production" is consistent with either explanation. Corrected `owasp-checklist.md`, `cd-workflows.md §1`, and `release-checklist.md`'s OWASP row. Flagged as the single most action-critical item outstanding in this project — genuinely unknown pending founder verification. No code change. |
