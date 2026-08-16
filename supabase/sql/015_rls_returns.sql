-- Sprint 33 (docs/17-sprints/sprint-33.md): RLS on `returns`, same standard template as
-- 003_rls_stores.sql / .../ 014_rls_customers.sql. `return_line_items` deliberately has no
-- independent RLS, mirroring 005_rls_sales.sql's own stated precedent for `sale_line_items`/
-- `sale_payments` — access is always via `return_id`, never queried directly across tenants.

alter table public.returns enable row level security;

create policy tenant_isolation on public.returns
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
