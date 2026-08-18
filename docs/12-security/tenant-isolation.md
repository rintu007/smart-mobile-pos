# Tenant Isolation

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.2.0
> **Last updated:** 2026-08-18
> **Owner:** Security Engineer / CTO
> **Approved by:** _pending_

The isolation mechanism is already fully specified in
[tenancy-model.md](../07-database/tenancy-model.md) (JWT claim, RLS policy template, the automated
cross-tenant negative test suite). This document's job, per this phase's charter, is the
**independent verification** — extending that proof to the one place Phase 07 didn't yet reach, and
stating explicitly what "independent" means here.

---

## 1. Why "independent" is the operative word

[tenancy-model.md §3](../07-database/tenancy-model.md#3-rls-is-never-bypassed-including-by-the-apis-own-connection)
already establishes that RLS is never bypassed, including by the API's own service-role connection.
The verification this phase's exit criterion demands — **automated tests prove cross-tenant access
fails on every table, not a sample** — must therefore itself be independent of the API layer being
correct: the test suite authenticates as a real tenant-scoped user and hits the database (or the
API, for the endpoints where that's the realistic attack path) exactly as an attacker would, rather
than asserting the *API's own code* looks correct by inspection.

## 2. What "every table" means precisely, restated as a checklist

**Corrected 2026-08-18, building the automated suite itself (Sprint 40, backlog.md M4 item 5) —
this checklist had drifted from the real, built schema in three ways, found by actually cross-checking
against `apps/web/prisma/schema.prisma` rather than trusting this document's own count:**

1. Five of the originally-listed 22 tables (`product_variants`, `batches`, `idempotency_keys`,
   `sync_rejections`, `devices`) **do not exist in the built schema at all** —
   `product_variants`/`batches` are named V2+/V4 stubs in schema-server.md itself;
   `idempotency_keys`/`sync_rejections` were never built; `devices` was explicitly dropped as a
   named, dated deviation (see `docs/modules/trading-day/specification.md §1` — no `devices` table
   exists, trading-day scoping uses `(tenant_id, store_id)` instead).
2. Two real, built, RLS-enabled tables were never listed here at all: `invoice_sequences` (Sprint
   24) and `customer_field_conflicts` (Sprint 35) — both added after this document's original
   2026-07-31 version, never folded back in.
3. `user_store_roles` was miscategorised as "scoped via a join to `users`, no own `tenant_id`" — it
   actually has its own direct `tenant_id` column (`010_rls_user_store_roles.sql`) and uses the
   standard direct-column policy, the same as every other Category-1 table. `devices` was the only
   genuine member of that category, and it doesn't exist (point 1) — **that category is empty**,
   removed below rather than left as a placeholder for a table that was never built.

Per the schema as actually built (19 real tables, not 22), categorised:

| Category | Tables | Test shape |
| --- | --- | --- |
| Direct `tenant_id` column | 15 of the 19: `stores`, `users`, `user_store_roles`, `audit_log`, `categories`, `units`, `products`, `customers`, `trading_days`, `sales`, `returns`, `shop_settings` (`tenant_id` is itself the primary key), `invoice_sequences`, `stock_movements`, `customer_field_conflicts` | [tenancy-model.md §5](../07-database/tenancy-model.md#5-the-proof-automated-cross-tenant-negative-test-suite)'s standard read/update/delete-by-ID attempt |
| Joined via parent (no own `tenant_id`) | `sale_line_items`, `sale_payments`, `return_line_items` | Same attempt shape, via the parent-join policy in [tenancy-model.md §2](../07-database/tenancy-model.md#2-the-rls-policy-template) — **found and closed a real gap building this suite**: these three tables had **no RLS enabled at all** until Sprint 40 (`005_rls_sales.sql`/`015_rls_returns.sql`'s own comments had claimed none was needed, relying solely on the API never issuing an unscoped query — exactly the single point of failure RLS-as-defence-in-depth exists not to depend on). Closed via `supabase/sql/017_rls_sale_line_items_sale_payments.sql`/`018_rls_return_line_items.sql`, the parent-join template this document already specified. |
| `tenants` itself | 1 table | A user may only ever read their own tenant row — tested as "tenant A's user cannot read tenant B's `tenants` row," the same shape applied to the boundary table itself |
| Store-scoped, second dimension (overlay, not an additional table count) | `stock_movements`, `trading_days`, `sales`, `returns` | **Not yet enforced by RLS, and not tested by the Sprint 40 suite** — no second policy dimension exists in any `supabase/sql/*.sql` file today; tenancy-model.md §4 itself frames this as "close to formality" given V1's one-store-per-tenant reality. Named here as a real, deferred gap (not silently untested) rather than written as a test that would legitimately fail because the enforcement it checks for was never built. |

**15 + 3 + 1 = 19 of 19 real tables accounted for.** (An earlier draft of this checklist omitted
`user_store_roles` and `devices` entirely, undercounting both the category list and the total — found
and corrected during Phase 18 pre-implementation review; superseded by the 2026-08-18 correction
above, which is the current, schema-accurate count.)

## 3. CI enforcement — not a one-time proof, and now real

**Built Sprint 40 (backlog.md M4 item 5)**: `.github/workflows/pr.yml`'s `fast-integration` job — a
fresh `postgres:15` service container per run (never a shared/production database, so concurrent PR
runs never pollute each other's state), migrations applied via `prisma migrate deploy`, then every
`supabase/sql/*.sql` RLS policy file applied in order, then
`apps/web/integration-tests/cross-tenant-isolation.test.ts` runs the read/update/delete-by-ID
attempt against all 19 tables above, authenticated as a real Postgres role (`authenticated`, no
`BYPASSRLS`) via `SET LOCAL request.jwt.claims` — the same mechanism a real Supabase-issued JWT
drives in production. **This is a correction to this section's own previous wording, found while
building it**: it previously restated tenancy-model.md §5's "runs in CI on every migration that
touches a tenant-owned table" framing, but backlog.md M4 item 5's actual instruction — and what was
actually built — is broader: **every PR, no path filter**, matching
[ci-pipeline.md §2](../14-testing/ci-pipeline.md#2-pipeline-stages--every-pull-request)/
[ci-workflows.md §1](../15-github-project/ci-workflows.md#1-pryml--every-pull-request)'s own
already-fixed framing, which this section had drifted from. A new table without a passing
cross-tenant test now genuinely blocks the PR that adds it — not a one-time proof, a live, running
gate. A tenant-isolation bug is silent by nature — nothing crashes, nothing errors for the
attacker, data simply leaks — which is exactly why this cannot be a manual pre-launch checklist
item; it has to be a gate a migration physically cannot pass without.

## 4. Extending the cross-tenant proof to Realtime

Phase 07's suite was written against direct table access (via the API's database connection,
authenticated as a specific tenant's user). Per [threat-model.md](threat-model.md)'s TB-2 finding —
Realtime is the **one** boundary with no API layer in front of it — this phase adds the missing
case explicitly: the same two-tenant fixture, but the negative test opens an actual Supabase
Realtime subscription as tenant A's authenticated user against a channel/table containing tenant B's
data, and asserts zero rows are ever received, for the full duration of the test, not just at
subscription-open time (a policy that correctly blocks the initial snapshot but leaks on a
subsequent change event would otherwise pass a naive test). This is the one net-new verification
this phase adds beyond what Phase 07 already specified — everything else in this document is making
Phase 07's existing guarantee complete and CI-enforced, not inventing a new mechanism.

**Deliberately not built by Sprint 40 (backlog.md M4 item 5) — a real, named, larger gap, not
silently dropped.** A genuine Realtime subscription needs a running Realtime server, which needs
the full local Supabase CLI stack (`supabase start` — Postgres + GoTrue + PostgREST + Realtime),
not the plain `postgres:15` service container `fast-integration` actually uses (§3). Standing that
up (config, GoTrue custom-access-token-hook wiring, CI runtime cost) is materially larger than the
rest of this sprint's scope and would have put the whole item's timeline at risk for one boundary
this codebase's own threat model (TB-2) already flags as lower-frequency than direct table access.
Tracked forward as a fast-follow, not tested today — §3's CI gate covers direct-connection RLS for
all 19 real tables; it does not yet cover this one boundary.

## 5. What remains an accepted, documented limit (not silently ignored)

Per [tenancy-model.md §6](../07-database/tenancy-model.md#6-what-rls-does-not-protect-against) and
restated here as this phase's own acceptance: a leaked JWT, an engineer manually bypassing RLS with
a superuser credential "to check something," and aggregate/statistical cross-tenant leakage are
outside what RLS-based isolation can address by construction. The first is mitigated by short token
lifetimes ([identity-and-sessions.md](identity-and-sessions.md)); the second is a process-discipline
rule stated in [ADR-0004](../adr/ADR-0004-shared-schema-multi-tenancy.md)'s compliance section, not
something this schema can enforce technically; the third is noted as not applicable to this
product's realistic threat model.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Full 22-table checklist against schema-server.md; CI-gate restated as binding; cross-tenant proof extended to the Realtime (TB-2) channel specifically. |
| 0.1.1 | 2026-07-31 | **Correction, found during a pre-Phase-18 documentation audit:** the checklist's own categories only summed to 19–21 tables, silently omitting `user_store_roles` and `devices` (neither has a direct `tenant_id` column nor fits the parent-join category as it was scoped). Added as their own category; the 16+3+2+1=22 accounting now actually matches the total it claims. |
| 0.2.0 | 2026-08-18 | Sprint 40 (backlog.md M4 item 5): the CI-enforced automated suite this document specifies actually built — `.github/workflows/pr.yml`'s `fast-integration` job, a fresh `postgres:15` container per PR, all 19 real tables. Three real corrections found while building it, not by inspection: the 22-table checklist itself had drifted from the schema (5 listed tables never built, 2 real tables never listed, `user_store_roles` miscategorised — §2's own note has the full breakdown); `sale_line_items`/`sale_payments`/`return_line_items` had **no RLS at all**, contradicting tenancy-model.md §2's own template — closed via two new migration files; §3's own "every migration touching a tenant-owned table" CI-placement wording had drifted from ci-pipeline.md/ci-workflows.md's already-fixed "every PR" framing — corrected to match what was actually built. §4's Realtime extension is named as a real, deferred gap (needs the full local Supabase CLI stack, materially larger scope) rather than built this sprint. |
