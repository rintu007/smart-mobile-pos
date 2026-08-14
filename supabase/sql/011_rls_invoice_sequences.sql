-- Sprint 24 (docs/17-sprints/sprint-24.md): RLS on `invoice_sequences`, same standard template as
-- every other table (003_rls_stores.sql through 010_rls_user_store_roles.sql) — `invoice_sequences`
-- has a `tenant_id` column, so no special-casing is needed. There is no client-direct read/write
-- path to this table at all (only pos/repository.ts's own transaction ever touches it), but the
-- policy exists as defence-in-depth regardless, matching every other table's own precedent.

alter table public.invoice_sequences enable row level security;

create policy tenant_isolation on public.invoice_sequences
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
