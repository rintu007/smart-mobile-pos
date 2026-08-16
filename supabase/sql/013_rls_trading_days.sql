-- Sprint 26 (docs/17-sprints/sprint-26.md): RLS on `trading_days`, same standard template as
-- every other table (003_rls_stores.sql through 012_rls_shop_settings.sql).

alter table public.trading_days enable row level security;

create policy tenant_isolation on public.trading_days
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
