# Tenant Isolation

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.1.1
> **Last updated:** 2026-07-31
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

Per [schema-server.md](../07-database/schema-server.md), all 22 tables, categorised:

| Category | Tables | Test shape |
| --- | --- | --- |
| Direct `tenant_id` column | 16 of the 22: `stores`, `users`, `audit_log`, `categories`, `units`, `products`, `product_variants`, `stock_movements`, `batches`, `customers`, `trading_days`, `sales`, `returns`, `shop_settings` (`tenant_id` is itself the primary key), `idempotency_keys`, `sync_rejections` | [tenancy-model.md §5](../07-database/tenancy-model.md#5-the-proof-automated-cross-tenant-negative-test-suite)'s standard read/update/delete-by-ID attempt |
| Joined via parent (no own `tenant_id`) | `sale_line_items`, `sale_payments`, `return_line_items` | Same attempt shape, via the parent-join policy in [tenancy-model.md §2](../07-database/tenancy-model.md#2-the-rls-policy-template) |
| Scoped via a join to `users` (no own `tenant_id`, and not a parent-row join in the sales/returns sense) | `user_store_roles`, `devices` | A dedicated test shape: tenant A's user must not be able to read/revoke tenant B's `user_store_roles`/`devices` row by ID, verified via the `user_id` join to `users.tenant_id` rather than a column on the row itself — easy to silently miss precisely *because* it isn't a direct column, which is why it is named as its own category here rather than folded into "joined via parent" |
| `tenants` itself | 1 table | A user may only ever read their own tenant row — tested as "tenant A's user cannot read tenant B's `tenants` row," the same shape applied to the boundary table itself |
| Store-scoped, second dimension (overlay, not an additional table count) | `stock_movements`, `trading_days`, `sales`, `returns` | The tenant-level test **plus** a second test: same-tenant, different-store access denied — per [tenancy-model.md §4](../07-database/tenancy-model.md#4-store-level-scoping-is-a-second-finer-grained-layer) |

**16 + 3 + 2 + 1 = 22 of 22 tables accounted for** — this table exists so a 23rd table added later
has an obvious place to be added to, and so this phase's exit criterion is checkable by counting
rows, not by trusting a claim of completeness. (An earlier draft of this checklist omitted
`user_store_roles` and `devices` entirely, undercounting both the category list and the total — found
and corrected during Phase 18 pre-implementation review, not left standing.)

## 3. CI enforcement — not a one-time proof

Restating [tenancy-model.md §5](../07-database/tenancy-model.md#5-the-proof-automated-cross-tenant-negative-test-suite)'s
own emphasis because it is the single most load-bearing operational fact in this entire security
model: this suite **runs in CI on every migration that touches a tenant-owned table**, and a new
table without a passing cross-tenant test **blocks the migration**. A tenant-isolation bug is
silent by nature — nothing crashes, nothing errors for the attacker, data simply leaks — which is
exactly why this cannot be a manual pre-launch checklist item; it has to be a gate a migration
physically cannot pass without.

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
