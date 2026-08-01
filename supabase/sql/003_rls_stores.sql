-- Sprint 02 (docs/17-sprints/sprint-02.md): RLS on `stores`, per the template in
-- docs/07-database/tenancy-model.md §2. `stores` has a `tenant_id` column (unlike `tenants`
-- itself), so this uses the standard template, not the `tenants` table's special-cased `id`
-- comparison (see 002_rls_tenants_users.sql).

alter table public.stores enable row level security;

create policy tenant_isolation on public.stores
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
