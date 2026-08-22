-- Diagnostic only — never a migration, never applied by CI, never run automatically.
-- Read-only: SELECT statements against system catalogs (pg_tables, pg_roles). Nothing here
-- modifies data, schema, or policies.
--
-- Purpose: answers, directly against the real database, the two open questions named in
-- docs/15-github-project/cd-workflows.md §1 and docs/12-security/owasp-checklist.md's finding #1:
--   1. Which tables actually have Row-Level Security ENABLED and FORCED right now — not what the
--      SQL files in this directory say should be true, what is actually true in this database.
--   2. Does the role this app's own DATABASE_URL connects as bypass RLS entirely (e.g. because it
--      is a superuser, or the owner of every table and RLS is enabled-but-not-forced)?
--
-- How to run: paste both queries into the Supabase Dashboard's SQL Editor for the PRODUCTION
-- project (not a local/test database) and read the results directly — no setup, no CLI, no
-- credentials beyond normal dashboard access.

-- ============================================================================
-- Query 1: RLS status for every table in the public schema
-- ============================================================================
-- Expected (if every migration in supabase/sql/002_ through 019_ was actually applied): every
-- row below shows rls_enabled = true. rls_forced should also be true for this to actually protect
-- anything against a connection using the table-owner role (see error-catalogue's/owasp-checklist's
-- FORCE finding) — but rls_forced = false does NOT by itself mean nothing is protected; it only
-- matters if the role in Query 2 turns out to be the table owner. Read both queries together.
--
-- If ANY row is missing entirely from this result (i.e. the table exists in the app but doesn't
-- appear here), or shows rls_enabled = false, that table's RLS policy was never actually applied
-- to this database — the exact question this script exists to answer for 017/018/019 specifically
-- (sale_line_items, sale_payments, return_line_items, devices), though every row is worth checking,
-- not just those three.
SELECT
  schemaname,
  tablename,
  rowsecurity      AS rls_enabled,
  (SELECT relforcerowsecurity FROM pg_class WHERE oid = (schemaname || '.' || tablename)::regclass)
                   AS rls_forced
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- ============================================================================
-- Query 2: does any role bypass RLS entirely?
-- ============================================================================
-- Find the username portion of this project's production DATABASE_URL (Vercel env vars —
-- postgresql://<username>:...@...) and look up that exact rolname in the results below.
--   - rolbypassrls = true, OR rolsuper = true  →  that role bypasses RLS on every table
--     regardless of rls_enabled/rls_forced above — this is the scenario owasp-checklist.md's
--     finding #1 describes as "very likely," now directly checkable instead of inferred.
--   - rolbypassrls = false and rolsuper = false →  RLS genuinely applies to this role's queries,
--     for every table where rls_enabled = true above (and additionally for every table where
--     rls_forced = true, if this role also happens to own the table).
SELECT
  rolname,
  rolsuper,
  rolbypassrls
FROM pg_roles
ORDER BY rolname;
