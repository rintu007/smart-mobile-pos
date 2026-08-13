-- Sprint 17 (docs/17-sprints/sprint-17.md): RLS on `categories`, same standard template as
-- 003_rls_stores.sql / 004_rls_products.sql / 005_rls_sales.sql / 006_rls_stock_movements.sql /
-- 007_rls_audit_log.sql — `categories` has a `tenant_id` column, so no special-casing is needed.

alter table public.categories enable row level security;

create policy tenant_isolation on public.categories
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
