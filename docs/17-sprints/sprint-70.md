# Sprint 70

> **Dates:** 2026-08-25 – 2026-08-26 (spans midnight, same single continuous session as every prior
> sprint)
> **Milestone:** none — a real fix following up on Sprint 69's own named findings, not milestone work
> **Status:** Closed.

## Goal

Sprint 69's Phase 07 documentation audit deliberately named four missing indexes and one missing
column as real, live gaps rather than fix them speculatively in a documentation-only pass. This
sprint builds the ones that turned out, on closer inspection, to actually need building — and
corrects Sprint 69's own mistake about one that didn't.

## What was found

Before writing any migration, each of Sprint 69's four named index gaps was re-verified against the
real query code that was supposed to need it — the same discipline Sprint 66 applied to a prior
session's own Dependabot diagnosis, turned here on this session's own prior finding.

1. **`sales(customer_id)` — confirmed real.** `customers/repository.ts#listPurchaseHistory` runs
   `prisma.sale.findMany({ where: { tenantId, customerId, status: "completed", ... } })`, cursor-
   paginated by `(completedAt, id)` desc. A real, live, unindexed query.
2. **`products(tenant_id, category_id)` — confirmed real.** `products/repository.ts#listProducts`
   applies `categoryId` as an optional `where` filter on every `GET /api/v1/products` call that
   supplies it. A real, live, unindexed query.
3. **`sale_line_items(product_id)` — Sprint 69 was wrong.** Re-checking the FR-073 top/slow-product
   report this index was supposed to serve: its own requirements-table row says `Fully offline`.
   Sprint 37's own implementation-log entry confirms it was built as pure local Drift aggregation on
   the mobile device, no server report endpoint. Grepped `apps/web/src` for any
   `saleLineItem.findMany`/`groupBy`/`aggregate` call — none exist. There is no query for this index
   to serve; Sprint 69 named a gap that was never actually a gap.
4. **`products(tenant_id, name text_pattern_ops)` — confirmed real, but not fixable the way Sprint 69
   assumed.** The actual query (`products/repository.ts#listProducts`) does
   `{ name: { contains: filters.search, mode: "insensitive" } }` — a middle-match `ILIKE '%text%'`
   scan. `text_pattern_ops` only accelerates left-anchored (`LIKE 'text%'`) patterns; it does nothing
   for a `contains` scan regardless of whether it's built. The actual fix is a `pg_trgm` trigram GIN
   index — a materially different, larger change (a Postgres extension, a different index type, its
   own dedicated live-database verification) than the plain B-tree index this document had assumed
   would work. Correctly re-scoped rather than built with the wrong tool.

## What was built

Migration `20260825175448_add_missing_indexes` — two plain `CREATE INDEX` statements, additive and
non-breaking:

```sql
CREATE INDEX "sales_tenant_id_customer_id_completed_at_idx" ON "sales"("tenant_id", "customer_id", "completed_at");
CREATE INDEX "products_tenant_id_category_id_idx" ON "products"("tenant_id", "category_id");
```

`schema.prisma` gains the matching `@@index([tenantId, customerId, completedAt])` on `Sale` and
`@@index([tenantId, categoryId])` on `Product`. The `sales` index is a composite matching
`listPurchaseHistory`'s actual query shape (tenant + customer filter, `completed_at`-ordered) — more
precise than `schema-server.md`'s own original bare `(customer_id)` claim.

`schema-server.md` corrected again in the same pass: both new indexes documented as built; the
`sale_line_items(product_id)` finding retracted with the FR-073/Sprint 37 evidence; the `products`
text-search finding re-scoped to name `pg_trgm` as the real fix rather than left implying the
originally-documented form would work.

## Design decisions

1. **Hand-write the migration SQL rather than generate it against a live database.** This repository
   has never had local Postgres/Docker infrastructure, unchanged since every prior sprint that has
   said the same thing (most recently Sprint 68). Matched Prisma's own generated SQL style exactly
   (`CREATE INDEX "table_col1_col2_idx" ON "table"("col1", "col2")`, confirmed against an existing
   migration file) rather than approximating it.
2. **Plain B-tree indexes, not the partial (`WHERE ... IS NOT NULL`) form `schema-server.md`
   originally documented.** Matches the precedent already established and accepted throughout this
   exact schema — `categories`/`units`/`products.barcode` were all documented with a partial-index
   form and built as plain indexes instead, named as acceptable drift in Sprint 69's own audit rather
   than something requiring a fix. A partial index is a size/write-overhead optimization here, not a
   correctness requirement (unlike `trading_days_one_open_per_store`'s hand-edited partial *unique*
   index, which enforces a real invariant) — not worth the extra hand-edited-migration risk for two
   straightforward additive indexes.
3. **Do not attempt the `pg_trgm` fix in this sprint.** Enabling a Postgres extension and building a
   GIN index is a different, larger kind of change than a plain B-tree `CREATE INDEX` — it needs its
   own dedicated verification against a live database (confirming the extension is actually
   available on the target Supabase project, confirming the GIN index actually accelerates the real
   query), not something to fold into a sprint that can otherwise be fully verified through
   `lint`/`typecheck`/`test`/`build` plus CI's `fast-integration` job alone.
4. **Correct Sprint 69's own mistake in the same document, not quietly.** The `sale_line_items(product_id)`
   retraction is written the same way every other correction in `schema-server.md` is — dated,
   attributed, with the evidence that disproved it — rather than silently dropped from the list.

## Definition of Done

- [x] `apps/web/prisma/schema.prisma` — two new `@@index` declarations (`Sale`, `Product`).
- [x] `apps/web/prisma/migrations/20260825175448_add_missing_indexes/migration.sql` (new) — matches
      the schema exactly, verified via CI's `fast-integration` `prisma migrate deploy` step (this
      repo's only venue for a real-database check).
- [x] `docs/07-database/schema-server.md` — both new indexes documented as built; the
      `sale_line_items(product_id)` finding retracted with evidence; the `products` text-search
      finding re-scoped to name the real fix (`pg_trgm`) rather than imply the wrong one would work.
- [x] Verified locally, `DATABASE_URL`/`DIRECT_URL` deliberately unset except where CI itself would
      set them: `lint` clean, `typecheck` clean, `test` 227/227, `prisma generate && build` (CI-style
      placeholder env vars) succeeds.
- [x] Verified in CI: `fast-integration` (`prisma migrate deploy` against a real ephemeral Postgres)
      green on this PR before merge.
- [x] `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md` updated in the
      same PR.
- [x] `sale_line_items.hsn_sac_code_at_sale` remains named, not built — a feature-shaped fix (a new
      column plus sale-creation snapshot logic), materially different in kind from an index addition,
      left for its own dedicated sprint.

## Demo script

**Local, run 2026-08-25/26:**

1. Re-verified all 4 of Sprint 69's named index gaps against real query code before writing any
   migration — found one (`sale_line_items(product_id)`) was itself a mistake, and one
   (`products` text-search) needed a different fix than originally assumed. ✅
2. `prisma generate` — succeeded against the updated schema. ✅
3. `pnpm --filter @smart-pos/web lint`/`typecheck` — both clean. ✅
4. `pnpm --filter @smart-pos/web test` — 227/227. ✅
5. `prisma generate && build` with CI's own placeholder env vars — succeeded. ✅

**Not performed this sprint, by design:** the `pg_trgm` GIN index fix for product text search, and
the `hsn_sac_code_at_sale` snapshot column — both real, both named, both left for their own
dedicated, separately-verified sprints.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Worth stating plainly: a documentation audit's own findings are not automatically correct just
because they were written down carefully — Sprint 69 named `sale_line_items(product_id)` as a real
gap without actually checking whether the query it was meant to serve existed server-side at all, and
it didn't. The fix is the same discipline this entire run of sprints has applied to *external* claims
(design docs, migration guides, a prior session's own summaries) — turned here, for the first time
explicitly, on this session's own prior-sprint output within the same session. Re-verifying your own
recent work before building on it is not redundant; it caught a real mistake here, one sprint later,
before any code was written against it.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-26 | Sprint 70: built 2 of Sprint 69's 4 named missing indexes (`sales(tenant_id, customer_id, completed_at)`, `products(tenant_id, category_id)`), both re-confirmed against live query code first. Found and corrected Sprint 69's own mistake: `sale_line_items(product_id)` was never a real gap (FR-073 is fully offline/local, no server query exists). Found the `products` text-search index needs `pg_trgm`, not the plain B-tree form originally documented — re-scoped rather than built wrong. `lint`/`typecheck`/`test` (227/227)/`build` verified clean; `fast-integration` verified in CI. `hsn_sac_code_at_sale` remains open for a dedicated follow-up sprint. |
