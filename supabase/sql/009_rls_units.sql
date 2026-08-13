-- Sprint 18 (docs/17-sprints/sprint-18.md): RLS on `units`, same standard template as
-- 003_rls_stores.sql / 004_rls_products.sql / 005_rls_sales.sql / 006_rls_stock_movements.sql /
-- 007_rls_audit_log.sql / 008_rls_categories.sql — `units` has a `tenant_id` column, so no
-- special-casing is needed.

alter table public.units enable row level security;

create policy tenant_isolation on public.units
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
