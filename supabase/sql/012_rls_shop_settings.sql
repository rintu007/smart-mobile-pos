-- Sprint 25 (docs/17-sprints/sprint-25.md): RLS on `shop_settings`, same standard template as
-- every other table (003_rls_stores.sql through 011_rls_invoice_sequences.sql). `tenant_id` is
-- this table's own primary key rather than an ordinary column, but the policy predicate is
-- identical either way -- `current_tenant_id()` compares against whichever column is named.

alter table public.shop_settings enable row level security;

create policy tenant_isolation on public.shop_settings
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
