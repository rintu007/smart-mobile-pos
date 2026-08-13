-- Sprint 23 (docs/17-sprints/sprint-23.md): RLS on `user_store_roles`, same standard template as
-- 003_rls_stores.sql / 004_rls_products.sql / 005_rls_sales.sql / 006_rls_stock_movements.sql /
-- 007_rls_audit_log.sql / 008_rls_categories.sql / 009_rls_units.sql — `user_store_roles` has a
-- `tenant_id` column, so no special-casing is needed. This table is server-authoritative
-- (docs/07-database/schema-server.md) — RLS still applies to every role, including the API's own
-- connection, per ADR-0004; there is no client-direct write path to this table at all (every write
-- goes through the roles module's own service, never PostgREST directly), but the policy exists as
-- defence-in-depth regardless, matching every other table's own precedent.

alter table public.user_store_roles enable row level security;

create policy tenant_isolation on public.user_store_roles
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
