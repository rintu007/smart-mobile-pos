-- Sprint 05 (docs/17-sprints/sprint-05.md): RLS on `sales`, same standard template as
-- 003_rls_stores.sql / 004_rls_products.sql. `sale_line_items`/`sale_payments` deliberately have
-- no independent RLS — matching docs/07-database/schema-server.md's own stated design (access is
-- via `sale_id`, never queried directly across tenants), per docs/modules/pos/specification.md §3.

alter table public.sales enable row level security;

create policy tenant_isolation on public.sales
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
