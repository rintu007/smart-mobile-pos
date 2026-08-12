-- Sprint 12 (docs/17-sprints/sprint-12.md): RLS on `audit_log`, same standard template as
-- 003_rls_stores.sql / 004_rls_products.sql / 005_rls_sales.sql / 006_rls_stock_movements.sql —
-- `audit_log` has a `tenant_id` column, so no special-casing is needed. No `UPDATE`/`DELETE`
-- grant is separately revoked here, matching `stock_movements`' own precedent (Sprint 11): the
-- "no update/delete" guarantee is enforced by construction (no code path calls either), not by a
-- database-level REVOKE — named the same way, not a new gap specific to this table.

alter table public.audit_log enable row level security;

create policy tenant_isolation on public.audit_log
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
