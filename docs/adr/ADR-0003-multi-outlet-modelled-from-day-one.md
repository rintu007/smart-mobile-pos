# ADR-0003 — Model Store-Level Scoping From the First Migration, Even Though Multi-Outlet UI Ships in V4

> **Status:** 🟢 Accepted
> **Date:** 2026-07-28
> **Phase:** 01 — Project Vision (resolves OD-05 ahead of Phase 07 so downstream phases aren't blocked)
> **Deciders:** CTO
> **Supersedes:** _none_

---

## Context

V1 targets single-outlet shops exclusively ([scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)).
Multi-outlet is deferred to V4. But the *database schema* has to decide now — at the very first
migration — whether stock, sales and users are scoped to a store or only to a tenant, because this
is exactly the class of change [07-database/README.md](../07-database/README.md) identifies as
the highest-stakes in the project: retrofitting scoping onto a live, append-only stock ledger with
real customer data is one of the most expensive migrations this domain has.

## Decision drivers

- The stock ledger (per [project-vision.md §9](../01-vision/project-vision.md)) is append-only and
  becomes large and load-bearing quickly; changing its grain after the fact means migrating history,
  not just adding a column.
- V4 multi-outlet is on the roadmap, not hypothetical — it's the primary lever for the "small chain"
  secondary persona in the vision.
- The cost of doing this now is small: one column and a default. The cost of doing it later is a
  migration against live financial data.

## Options considered

### Option A — Tenant-scoped only in V1; add store scoping when V4 is built
| Pros | Cons |
| --- | --- |
| Nothing to build now | Migrating the stock ledger and sales history to add store scoping later touches every financial table with live data |

### Option B — Model `store_id` on every stock, sales and user-assignment record from the first migration; V1 creates exactly one store per tenant and never exposes a selector
| Pros | Cons |
| --- | --- |
| V4 multi-outlet becomes additive (new UI, new queries) instead of a schema migration on financial history | Slightly more schema/discipline overhead now (every write must set `store_id`, even when there's only one) |
| Zero UI or product complexity added in V1 — the concept stays fully hidden | |

## Decision

We will adopt **Option B**. Every stock movement, sale, and store-scoped user assignment carries a
`store_id` foreign key from the first migration onward. V1's onboarding flow creates exactly one
store per tenant automatically and the interface never surfaces a store selector or store-management
screen — the concept exists in data only, not in anything a V1 user can see or configure.

This does not mean building warehouse management, stock transfer, or any V4 feature now. It means
the *grain* of the data is right from day one so those features are additive later.

## Consequences

**Positive**
- V4 multi-outlet ships without a migration against live financial data.
- Reporting and stock-ledger queries are written against the correct grain from the start, so they
  don't need rewriting when a second store is added later — only a filter removed.

**Negative — accepted costs**
- Every V1 write path must correctly set `store_id`, even though it's always the same value. This
  is a discipline cost enforced by schema constraints (`NOT NULL`), not by convention.
- Slightly more complex seed/onboarding logic (create tenant → create default store → attach user)
  than a tenant-only model would need.

**Neutral**
- This decision does not resolve the multi-tenancy model itself (shared schema vs schema-per-tenant)
  — that remains open in the [ADR backlog](README.md) and is a separate, still-larger decision for
  Phase 07.

## Compliance

- Every migration adding a stock, sales, or store-scoped table is reviewed against: "does this
  table carry `store_id`, and is it `NOT NULL`?"
- Phase 07's `tenancy-model.md` and `stock-ledger.md` deliverables reference this ADR explicitly.

## Revisit when

Never, barring a fundamental rethink of the product's outlet model — this is the kind of decision
meant to not need revisiting.
