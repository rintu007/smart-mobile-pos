# Tenancy Model

> **Status:** 🔵 In review
> **Phase:** 07 — Database Design
> **Version:** 0.2.0
> **Last updated:** 2026-08-19
> **Owner:** PostgreSQL Architect / CTO
> **Approved by:** _pending_

The *rationale* for shared-schema tenancy is [ADR-0004](../adr/ADR-0004-shared-schema-multi-tenancy.md).
This document is the *mechanism*: how a tenant boundary is actually enforced, and how we prove it
holds — directly satisfying this phase's exit criterion that every tenant-scoped table has an RLS
policy **and** a test proving a wrong-tenant read fails.

---

## 1. How a request knows which tenant it is

At login, the API resolves the authenticated user's `tenant_id` (from the `users` table, via
`auth_user_id`) and embeds it as a custom claim in the session. Every subsequent request — whether
through the API (TB-1) or a direct Realtime subscription (TB-2) — carries this claim. A
`current_tenant_id()` SQL function resolves it from the request's JWT for use in RLS policies:

```sql
create or replace function current_tenant_id() returns uuid
language sql stable
as $$
  select (auth.jwt() ->> 'tenant_id')::uuid
$$;
```

**The claim is set once, server-side, at login — never accepted as a client-supplied parameter.** A
client cannot request "act as tenant X"; the claim is baked into the token the server issued.

## 2. The RLS policy template

Applied identically to every tenant-owned table (all 22 in [schema-server.md](schema-server.md)
except the local-only concept doesn't apply here — this is server-side):

```sql
alter table <table_name> enable row level security;

create policy tenant_isolation on <table_name>
  using (tenant_id = current_tenant_id())
  with check (tenant_id = current_tenant_id());
```

`USING` governs reads (and is what protects TB-2, the Realtime boundary, where RLS is the *only*
gate per [system-context.md](../04-srs/system-context.md)). `WITH CHECK` governs writes, protecting
against a tenant somehow being able to write a row claiming another tenant's `tenant_id` even
through the API's service-role connection — defence in depth means this holds even though the API
is also expected to set `tenant_id` correctly itself.

**Tables without a direct `tenant_id` column** (`sale_line_items`, `sale_payments`,
`return_line_items`) are protected by a policy that joins to their parent (`sales`/`returns`) rather
than duplicating `tenant_id` onto every child row:

```sql
create policy tenant_isolation on sale_line_items
  using (exists (
    select 1 from sales
    where sales.id = sale_line_items.sale_id
    and sales.tenant_id = current_tenant_id()
  ));
```

## 3. RLS is never bypassed, including by the API's own connection

Per [ADR-0004](../adr/ADR-0004-shared-schema-multi-tenancy.md), RLS is enabled **unconditionally**
— the API's service-role database connection does not use `BYPASSRLS`. The API's own service-layer
authorisation checks (TB-1, TB-3) are the first line; RLS is the second, independent one. This is a
deliberate redundancy: if the API's own tenant-scoping logic has a bug, RLS still stops the leak.

**Correction, found Sprint 43 (backlog.md M4 item 8, [owasp-checklist.md](../12-security/owasp-checklist.md)
A01):** this section states the *design intent* correctly, but no `ALTER TABLE ... FORCE ROW LEVEL
SECURITY` exists anywhere in `supabase/sql/*.sql`, and `BYPASSRLS` is the wrong thing to have
checked — Postgres exempts a table's own **owner** from its own RLS policies regardless of `ENABLE`,
independent of `BYPASSRLS`, unless `FORCE` is also set. The role `prisma migrate deploy` runs as (the
same `DATABASE_URL` the running app uses) becomes the owner of every table it creates. Whether this
"second, independent" layer actually holds in production today depends entirely on whether the real
`DATABASE_URL` role is deliberately *not* the table owner — something no code in this repository
confirms one way or the other. Flagged, not fixed: applying `FORCE` without first confirming the
real production role risks every tenant-scoped query suddenly returning zero rows.

## 4. Store-level scoping is a second, finer-grained layer

Tables that are store-scoped as well as tenant-scoped (`stock_movements`, `trading_days`, `sales`,
`returns`) get a second policy dimension checking `store_id` against the stores the authenticated
user currently holds a role at (`user_store_roles`, `revoked_at IS NULL`). In V1, with one store per
tenant, this is close to a formality — but it is written now, not deferred, per
[ADR-0003](../adr/ADR-0003-multi-outlet-modelled-from-day-one.md), so multi-store tenants in V4 are
already correctly isolated from each other's stores without a policy rewrite.

## 5. The proof: automated cross-tenant negative test suite

**This is the concrete instrument for this phase's exit criterion**, not a one-off manual check. For
every tenant-owned table, an automated test:

1. Creates two tenants, A and B, each with their own row(s) in the table under test.
2. Authenticates as a user belonging to tenant A.
3. Attempts to read, update, and delete tenant B's row by ID (not by listing — a direct, targeted
   attempt, since an attacker who has somehow learned or guessed an ID is the realistic threat model).
4. Asserts every attempt returns an empty result or is rejected — **never** tenant B's data, and
   never a generic 500 error that might leak existence information either.

This suite runs in CI on every migration that touches a tenant-owned table, per
[NFR-019](../03-functional-requirements/non-functional-requirements.md) and
[QA-004](../04-srs/quality-attributes.md). A new table without this test passing blocks the
migration — stated in [ADR-0004](../adr/ADR-0004-shared-schema-multi-tenancy.md)'s compliance
section and repeated here because it is the single most important operational guarantee in this
entire phase.

## 6. What RLS does not protect against

RLS protects row-level read/write isolation. It does **not** protect against:
- A leaked JWT itself (mitigated by short token lifetimes and remote device revocation,
  [BR-005](../02-business-requirements/business-requirements.md)).
- An engineer manually querying the database with a superuser/bypass role "just to check
  something" — explicitly forbidden by [ADR-0004](../adr/ADR-0004-shared-schema-multi-tenancy.md)'s
  compliance section, a process discipline this schema cannot enforce by itself.
- Aggregate/statistical leakage (e.g. an endpoint that reveals "how many tenants exist" indirectly)
  — not a concern for this product's threat model, noted for completeness.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial tenancy mechanism: JWT claim design, RLS policy template, cross-tenant negative test suite specification. |
| 0.2.0 | 2026-08-19 | §3 corrected (Sprint 43, backlog.md M4 item 8): the "RLS is never bypassed" claim checked the wrong mechanism (`BYPASSRLS`) — the real risk is the table-owner exemption, uncontrolled by `FORCE ROW LEVEL SECURITY` (absent from every migration) and unconfirmed against the real production connection's role. Flagged as the most significant finding of the OWASP-checklist-against-real-code review, not fixed pending founder confirmation of production's actual `DATABASE_URL` role. |
