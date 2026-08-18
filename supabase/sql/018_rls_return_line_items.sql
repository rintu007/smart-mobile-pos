-- Sprint 40 (docs/17-sprints/sprint-40.md, backlog.md M4 item 5) — same real gap `017_rls_sale_line_items_sale_payments.sql`
-- closes, for `return_line_items`: `015_rls_returns.sql`'s own comment claimed no independent RLS
-- was needed here either, mirroring `sale_line_items`' now-corrected precedent. Closed the same way.

alter table public.return_line_items enable row level security;

create policy tenant_isolation on public.return_line_items
  using (exists (
    select 1 from public.returns
    where returns.id = return_line_items.return_id
    and returns.tenant_id = public.current_tenant_id()
  ))
  with check (exists (
    select 1 from public.returns
    where returns.id = return_line_items.return_id
    and returns.tenant_id = public.current_tenant_id()
  ));
