-- Sprint 04 (docs/17-sprints/sprint-04.md): RLS on `products`, same standard template as
-- 003_rls_stores.sql — `products` has a `tenant_id` column, so no special-casing is needed.

alter table public.products enable row level security;

create policy tenant_isolation on public.products
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
