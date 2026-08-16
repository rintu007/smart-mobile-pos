-- Sprint 31 (docs/17-sprints/sprint-31.md): RLS on `customers`, same standard template as
-- 003_rls_stores.sql / 004_rls_products.sql / .../ 013_rls_trading_days.sql — `customers` has a
-- `tenant_id` column, so no special-casing is needed.

alter table public.customers enable row level security;

create policy tenant_isolation on public.customers
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
