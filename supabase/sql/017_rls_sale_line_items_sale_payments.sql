-- Sprint 40 (docs/17-sprints/sprint-40.md, backlog.md M4 item 5): a real gap found while building
-- the CI-enforced cross-tenant isolation suite, not by inspection. `005_rls_sales.sql`'s own
-- comment claimed `sale_line_items`/`sale_payments` "deliberately have no independent RLS... access
-- is always via `sale_id`, never queried directly across tenants" — but tenancy-model.md §2 already
-- specifies the exact parent-join policy template these two tables need, and relying solely on the
-- API never issuing an unscoped query is exactly the single point of failure RLS-as-defence-in-depth
-- (tenancy-model.md §3, ADR-0004) exists to not depend on. Closed here rather than left standing:
-- a direct database connection with no RLS on these two tables could read/write any tenant's line
-- items or payments by ID, with no second gate if the API layer's own scoping ever had a bug.

alter table public.sale_line_items enable row level security;

create policy tenant_isolation on public.sale_line_items
  using (exists (
    select 1 from public.sales
    where sales.id = sale_line_items.sale_id
    and sales.tenant_id = public.current_tenant_id()
  ))
  with check (exists (
    select 1 from public.sales
    where sales.id = sale_line_items.sale_id
    and sales.tenant_id = public.current_tenant_id()
  ));

alter table public.sale_payments enable row level security;

create policy tenant_isolation on public.sale_payments
  using (exists (
    select 1 from public.sales
    where sales.id = sale_payments.sale_id
    and sales.tenant_id = public.current_tenant_id()
  ))
  with check (exists (
    select 1 from public.sales
    where sales.id = sale_payments.sale_id
    and sales.tenant_id = public.current_tenant_id()
  ));
