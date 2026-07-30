# ADR-0004 — Shared Schema with Row-Level Tenant Scoping, Not Schema-Per-Tenant

> **Status:** 🟢 Accepted
> **Date:** 2026-07-30
> **Phase:** 07 — Database Design
> **Deciders:** CTO / PostgreSQL Architect
> **Supersedes:** _none_

---

## Context

Every tenant-scoped table needs a tenancy model before a single migration is written — retrofitting
tenant isolation onto live financial data is, per this phase's own charter, one of the most
expensive migrations that exists. [cost-model.md §4](../02-business-requirements/cost-model.md)
already surfaced a strong, data-driven finding while modelling infrastructure cost: Supabase bills
per project, with a $25/month Pro floor. A schema-per-tenant (or project-per-tenant) model would
mean paying at least $25/month *per tenant* — incompatible with the free/low-cost tier the entire
pricing strategy in [pricing-strategy.md](../02-business-requirements/pricing-strategy.md) depends
on. This ADR formally ratifies that finding as a database-design decision, since the backlog in
[docs/adr/README.md](README.md) listed it as still open pending Phase 07.

## Decision drivers

- Per-tenant hosting cost must stay near-zero at low tenant counts, per the cost model.
- [ADR-0001](ADR-0001-hybrid-api-and-direct-realtime-access.md) already commits to RLS as the
  **sole** enforcement layer for the Realtime read boundary (TB-2) — RLS correctness is a load-bearing
  requirement regardless of which tenancy model is chosen, so its cost is not a marginal factor here.
- Tenant isolation is declared absolute in [project-vision.md §8](../01-vision/project-vision.md)
  Principle 8 — the model chosen must make that guarantee checkable, not just plausible.
- A small team must be able to run one migration, once, and have it apply correctly to every tenant.

## Options considered

### Option A — Schema-per-tenant or project-per-tenant
A separate Postgres schema (or separate Supabase project) for each tenant.

| Pros | Cons |
| --- | --- |
| Strongest possible physical isolation | $25+/month per tenant on Supabase's pricing — economically incompatible with a free tier |
| A bug in one tenant's schema can't structurally touch another's | Migrations must run N times, once per tenant, as the tenant count grows — an operational burden that scales linearly with success |
| | Cross-tenant reporting/analytics (even our own internal ones) becomes a federation problem |

### Option B — Shared schema, tenant_id column, Row Level Security
One set of tables; every tenant-scoped row carries a `tenant_id`; RLS policies filter by it.

| Pros | Cons |
| --- | --- |
| One migration applies to every tenant at once | Isolation is enforced by policy correctness, not physical separation — a missing or wrong RLS policy is a real, direct risk |
| Matches the $25/month-flat-regardless-of-tenant-count cost model this business depends on | Every query must be reviewed for correct tenant scoping; a forgotten `WHERE tenant_id = ...` in raw SQL bypassing RLS would be a leak |
| Consistent with ADR-0001's existing reliance on RLS | |

## Decision

We will adopt **Option B: shared schema, tenant-scoped by a `tenant_id` column on every
tenant-owned table**, enforced by Row Level Security as an independent second line of defence behind
the API-layer checks already established in [ADR-0001](ADR-0001-hybrid-api-and-direct-realtime-access.md).

Concretely:
- Every tenant-owned table has a non-nullable `tenant_id UUID REFERENCES tenants(id)`.
- Every such table has an RLS policy: `USING (tenant_id = current_tenant_id())`, where
  `current_tenant_id()` resolves from the authenticated session's JWT claim — never from a
  client-supplied parameter.
- RLS is **always enabled**, including for the service-role connection used by the API server,
  except where the API explicitly and deliberately needs cross-tenant access (there is no such V1
  case) — defence in depth means the API's own tenant-scoping logic is not trusted to be the only
  thing standing between tenants.
- Every table addition is reviewed against: "does this have a `tenant_id` and a policy?" A missing
  answer to either blocks the migration, per this phase's own exit criteria.

## Consequences

**Positive**
- Per-tenant cost stays near the modelled floor from [cost-model.md](../02-business-requirements/cost-model.md)
  regardless of tenant count.
- One migration, one apply, for every tenant — matches a small team's operational capacity.
- RLS policies are directly testable: a fixed, automated cross-tenant negative-read test suite (per
  [NFR-019](../03-functional-requirements/non-functional-requirements.md)) becomes the enforcement
  mechanism, not a hope.

**Negative — accepted costs**
- Isolation is a **policy correctness** property, not a physical one. Every new table is a place
  this can be got wrong, forever — mitigated, not eliminated, by making the negative test suite a
  required CI gate on every migration.
- Any raw/administrative SQL access that bypasses RLS (e.g. a debugging session using a superuser
  role) is a real leak vector — the team must never query the database directly with an
  RLS-bypassing role for anything touching tenant data, even for "just checking something."

**Neutral**
- Store-level scoping ([ADR-0003](ADR-0003-multi-outlet-modelled-from-day-one.md)) is a separate,
  finer-grained concern layered on top of tenant scoping — a table can be tenant-scoped without
  being store-scoped (e.g. `products`, per [tenancy-model.md](../07-database/tenancy-model.md)).

## Compliance

- Migration review checklist: every new tenant-owned table must have `tenant_id NOT NULL` and an
  RLS policy in the same migration, or the migration is rejected.
- Automated cross-tenant negative-read test suite runs on every migration in CI — this is the
  concrete instrument for [NFR-019](../03-functional-requirements/non-functional-requirements.md)
  and [QA-004](../04-srs/quality-attributes.md).
- No engineer connects to the production database with a role that bypasses RLS for routine work.

## Revisit when

A specific tenant requires physical data isolation for a contractual or regulatory reason no RLS
policy can satisfy (e.g. a dedicated-infrastructure enterprise contract) — at that scale, a hybrid
model (shared schema for most tenants, a dedicated schema for that one) is the more likely answer
than moving everyone to Option A.
