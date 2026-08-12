-- Sprint 11 (docs/17-sprints/sprint-11.md): RLS on `stock_movements`, same standard template as
-- 003_rls_stores.sql / 004_rls_products.sql / 005_rls_sales.sql — `stock_movements` has a
-- `tenant_id` column, so no special-casing is needed.

alter table public.stock_movements enable row level security;

create policy tenant_isolation on public.stock_movements
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
