# Sprint 62

> **Dates:** 2026-08-21 – 2026-08-21 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting deliverable, not a
> numbered backlog item — the first sprint in this run that builds something new rather than
> correcting or verifying an existing claim)
> **Status:** Closed. A ready-to-run diagnostic, not another finding.

## Goal

Sprint 59's own finding and `owasp-checklist.md`'s finding #1 both end at the identical wall: "this
session cannot check the real production database directly." That's true, and it isn't something
this session can fix — but leaving the founder with an open-ended "go figure out how to check this"
is a worse handoff than it needs to be. This sprint closes that gap the only way available: writing
the exact check, ready to run, so the founder's own remaining task shrinks from "investigate" to
"paste and read."

## What was built

`supabase/sql/diagnostics/check_rls_status.sql` — two read-only queries against Postgres's own
system catalogs, safe to paste directly into the Supabase Dashboard's SQL Editor for the production
project:

1. **Every table's actual RLS state right now.** `SELECT ... rowsecurity, relforcerowsecurity FROM
   pg_tables ...` — answers Sprint 59's own question directly: not what the migration files in
   `supabase/sql/002_` through `019_` say should be true, but what is actually true in the database
   today. A table missing from the result entirely, or showing `rls_enabled = false`, means that
   table's policy was never applied — the exact open question for `017`, `018`, and `019`
   specifically, though the query checks every table, not just those three.
2. **Every role's RLS-bypass status.** `SELECT rolname, rolsuper, rolbypassrls FROM pg_roles ...` —
   answers `owasp-checklist.md`'s finding #1 directly: find the username in the production
   `DATABASE_URL` (Vercel env vars) and look up that exact `rolname` in the result. `rolbypassrls`
   or `rolsuper` being true for that role means it bypasses RLS entirely, on every table, regardless
   of what Query 1 shows — this was previously "very likely" by inference; the query makes it a
   direct fact.

## Design decisions

1. **A file, not just instructions in a doc.** A ready-to-copy-paste `.sql` file, version-controlled
   alongside the actual policy files it audits, is more durable and less error-prone than asking the
   founder to retype or reconstruct a query from prose.
2. **Its own subdirectory, deliberately outside the numbered sequence.** `supabase/sql/002_` through
   `019_` are real migrations, applied in order, by hand, to production — `apply-sql.mjs` and any
   future automated deploy mechanism walk that directory expecting exactly that. A diagnostic script
   sitting in the same directory, even clearly named, risks eventually being swept into that
   sequence by a future tool or a tired 2am merge. `diagnostics/` makes that structurally
   impossible, not just discouraged by naming convention.
3. **Read-only, and said so explicitly, twice.** The script's own header states plainly it is
   diagnostic-only, never a migration, never applied by CI or automatically — given what it's
   answering (a question about a security-critical production system), the file should not require
   trusting a docstring alone to know it's safe to run.
4. **Answer both open questions in one script, not two.** Sprint 59's finding and
   `owasp-checklist.md`'s FORCE/role finding are related but distinct — resolving this the way it
   was framed elsewhere in this run of sprints (RLS-application as a precondition for the FORCE/role
   question) meant the founder would otherwise need to run one check, wait, then come back for a
   second. One paste, both answers.
5. **Reference it from every place a reader would actually look**, not just the file that prompted
   writing it — `cd-workflows.md §1`, `owasp-checklist.md`'s finding #1, and `release-checklist.md`'s
   OWASP row all now point to it directly.

## Definition of Done

- [x] `supabase/sql/diagnostics/check_rls_status.sql` (NEW) — two read-only queries, documented
      inline with expected-good/expected-bad interpretation for each.
- [x] Referenced from `cd-workflows.md §1`, `owasp-checklist.md`'s finding #1, and
      `release-checklist.md`'s OWASP row.
- [x] `backlog.md`, `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md`
      updated in the same PR.
- [x] Confirmed the script touches nothing outside `SELECT` statements against system catalogs — no
      `INSERT`/`UPDATE`/`DELETE`/`ALTER`/`CREATE` anywhere in the file.

## Demo script

**Local, run 2026-08-21:**

1. Verified the script contains only `SELECT` statements — no DDL, no DML, nothing that could alter
   schema, policies, or data even if run against the wrong database by mistake. ✅
2. Confirmed both queries are syntactically valid standard Postgres (system catalog columns
   `pg_tables.rowsecurity`, `pg_class.relforcerowsecurity`, `pg_roles.rolbypassrls`/`rolsuper` are
   all real, standard columns, not Supabase-specific extensions that might not exist). ✅

**Not performed, and cannot be performed by this session:** actually running the script against the
real production database. That is exactly the founder action this sprint exists to make easier, not
a step this session can complete on its own behalf.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Worth naming: Sprints 57 through 61 were all a form of the same activity — checking a claim against
reality, then correcting the claim. This sprint is different in kind, not degree: nothing was wrong,
nothing needed correcting, and no new fact was discovered about this project's own state. The value
here is entirely in reducing the distance between "the founder knows what needs checking" and "the
founder has actually checked it" — a different, but equally legitimate, way to close the same gap
that documentation corrections have been closing all session.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-21 | Sprint 62: added `supabase/sql/diagnostics/check_rls_status.sql`, a read-only diagnostic answering both Sprint 59's RLS-application question and `owasp-checklist.md`'s FORCE/role question directly against the real production database. Referenced from `cd-workflows.md §1`, `owasp-checklist.md`'s finding #1, and `release-checklist.md`'s OWASP row. |
