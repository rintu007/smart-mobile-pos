-- Sprint 01 (docs/17-sprints/sprint-01.md, item 2): the Custom Access Token Hook that injects
-- `tenant_id` into every Supabase-issued JWT, per docs/11-api/authentication.md §1 and
-- docs/07-database/tenancy-model.md §1.
--
-- Apply this against a real Supabase project's SQL editor, then wire it up as the project's
-- "Custom Access Token" Auth Hook in Dashboard -> Authentication -> Hooks (Beta) — the exact
-- dashboard steps are confirmed against Supabase's current documentation at the time this is
-- applied, per this project's standing practice of not committing to unverified tool specifics
-- ahead of the point where they're actually used (docs/adr/ADR-0007, docs/11-api/authentication.md §1).

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  claims jsonb;
  resolved_tenant_id uuid;
begin
  select tenant_id into resolved_tenant_id
  from public.users
  where auth_user_id = (event ->> 'user_id')::uuid;

  claims := event -> 'claims';

  if resolved_tenant_id is not null then
    claims := jsonb_set(claims, '{tenant_id}', to_jsonb(resolved_tenant_id));
  end if;

  event := jsonb_set(event, '{claims}', claims);
  return event;
end;
$$;

-- Supabase's auth admin role must be able to execute this hook.
grant execute on function public.custom_access_token_hook to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook from authenticated, anon, public;

-- The SQL-side counterpart to the hook above: reads the tenant_id claim it injected, for use in
-- every RLS policy — per docs/07-database/tenancy-model.md §1. Not load-bearing until the first
-- tenant-scoped table (beyond `users`/`tenants`/`stores`) actually enables RLS in a later sprint,
-- but defined now since it's one function, needed everywhere, and cheap to add early.
create or replace function public.current_tenant_id()
returns uuid
language sql
stable
as $$
  select (auth.jwt() ->> 'tenant_id')::uuid
$$;
