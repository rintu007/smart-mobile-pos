-- Sprint 35 (docs/17-sprints/sprint-35.md): RLS on `customer_field_conflicts`, same standard
-- template as 003_rls_stores.sql / .../ 015_rls_returns.sql.

alter table public.customer_field_conflicts enable row level security;

create policy tenant_isolation on public.customer_field_conflicts
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
