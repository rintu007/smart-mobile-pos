-- Sprint 01 demo script (docs/17-sprints/sprint-01.md, step 4): RLS on the two tables that exist
-- so far, per the template in docs/07-database/tenancy-model.md §2. The remaining 20 tables get
-- their own RLS migration when they're created, module by module — not batched ahead of time.

alter table public.tenants enable row level security;

-- `tenants` has no `tenant_id` column of its own — its `id` *is* the tenant identifier, so the
-- policy compares `id` directly rather than the standard `tenant_id = current_tenant_id()` template.
create policy tenant_isolation on public.tenants
  using (id = public.current_tenant_id())
  with check (id = public.current_tenant_id());

alter table public.users enable row level security;

create policy tenant_isolation on public.users
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());
