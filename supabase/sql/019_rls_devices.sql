-- Sprint 55 (docs/17-sprints/sprint-55.md) — the `devices` table (docs/07-database/schema-server.md
-- Context 1) has no direct `tenant_id` column, per that section's own design: "Tenant scoping:
-- tenant-scoped (via `user_id`)." Same parent-join RLS shape `sale_line_items`/`sale_payments`/
-- `return_line_items` already use (017_/018_), joining through `users` instead of `sales`/`returns`.

alter table public.devices enable row level security;

create policy tenant_isolation on public.devices
  using (exists (
    select 1 from public.users
    where users.id = devices.user_id
    and users.tenant_id = public.current_tenant_id()
  ))
  with check (exists (
    select 1 from public.users
    where users.id = devices.user_id
    and users.tenant_id = public.current_tenant_id()
  ));
