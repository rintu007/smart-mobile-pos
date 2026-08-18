-- Sprint 40 (backlog.md M4 item 5) — a minimal stand-in for Supabase's real `auth` schema. Real
-- Supabase (Postgres image + GoTrue) ships a full `auth` schema; this CI job runs plain
-- `postgres:15` instead (no GoTrue/PostgREST/Realtime), so only the one piece this codebase's own
-- RLS policies actually call is stubbed: `auth.jwt()`, read by `public.current_tenant_id()`
-- (supabase/sql/001_custom_access_token_hook.sql) — confirmed by grep to be the *only* `auth.*`
-- call site anywhere in supabase/sql/, so this stub is faithful to what's actually under test, not
-- a broader simulation. The function body below matches Supabase's own published implementation
-- for this exact shape (read the `request.jwt.claims` session variable), so the RLS policies run
-- completely unmodified against real Postgres row-level security.
create schema if not exists auth;

create or replace function auth.jwt() returns jsonb
language sql stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;

-- Non-superuser roles standing in for Supabase's own `authenticated`/`anon`/`supabase_auth_admin`
-- roles — `001_custom_access_token_hook.sql` and every RLS policy file reference these by name
-- (grep-confirmed, the only three roles named anywhere in supabase/sql/), so they must exist for
-- those files to apply completely unmodified. `authenticated` is the one the test suite actually
-- switches to per-transaction (`SET LOCAL ROLE`) — it owns no tables and has no BYPASSRLS, so RLS
-- applies to it exactly as it would to a real Supabase connection. `nologin` on all three since
-- nothing here authenticates by password; the suite always connects as the default (owning) role
-- and downgrades via `SET LOCAL ROLE` within a transaction.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    create role supabase_auth_admin nologin;
  end if;
end
$$;

grant usage on schema public to authenticated;
grant usage on schema auth to authenticated;
grant execute on function auth.jwt() to authenticated;
-- Broad on purpose: this is a throwaway per-CI-run database and the suite is testing row
-- visibility (RLS), not the outer table-privilege boundary — production's own GRANTs (set up by
-- Supabase itself) are a separate, already-correct concern this suite isn't re-verifying.
grant select, insert, update, delete on all tables in schema public to authenticated;
