# Sprint 72

> **Dates:** 2026-08-26 (single-day)
> **Milestone:** none — a real fix closing the last of Sprint 69/70's own named findings, not
> milestone work
> **Status:** Closed.

## Goal

Sprint 70 re-scoped the `products` text-search index rather than build it with the wrong tool —
`schema-server.md`'s original `(tenant_id, name text_pattern_ops)` claim would never have accelerated
`listProducts`'s real `contains`-based search, and building it anyway would have been documentation
theatre (a real migration, a real index, doing nothing for the query it claims to serve). This sprint
builds the index that actually works.

## What was built

Migration `20260825183908_add_products_trgm_search_index`, hand-edited (matching the
`trading_days_one_open_per_store` convention already established for anything Prisma's schema DSL
can't express — no operator-class/GIN syntax exists in Prisma's schema language):

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX "products_name_trgm_idx" ON "products" USING GIN ("name" gin_trgm_ops);
CREATE INDEX "products_sku_trgm_idx" ON "products" USING GIN ("sku" gin_trgm_ops);
```

Both `name` and `sku` are indexed, matching `listProducts`'s actual `OR` search across both columns.
No application-code change — the existing `contains`/`mode: "insensitive"` filter already produces
exactly the `ILIKE '%text%'` pattern trigram indexes accelerate; this was purely a missing-index
problem, not a query-shape problem.

`schema-server.md` corrected to document both indexes as built, replacing Sprint 70's own "left
unbuilt, correctly re-scoped" note.

## Design decisions

1. **`pg_trgm`, not a full-text-search (`tsvector`/`GIN`) column.** The real query is a substring
   `contains` match against short catalogue fields (product names, SKUs) — exactly what trigram
   indexes are built for. Full-text search (stemming, ranking, `tsvector` generated columns) solves a
   different problem (natural-language relevance ranking) this query was never asking for, and would
   need a schema change (a new indexed column) rather than an index alone.
2. **Index both `name` and `sku`, not just `name`.** `listProducts`'s search is a single `OR` across
   both columns — indexing only `name` would leave the `sku` half of every search unaccelerated,
   silently defeating half the fix.
3. **`CREATE EXTENSION IF NOT EXISTS`, not assumed already present.** `pg_trgm` ships in Postgres's
   standard contrib modules and is available on Supabase without a paid add-on, but nothing in this
   repository had ever enabled it — stated explicitly in the migration rather than assumed.
4. **No `schema.prisma` change.** Matches the exact precedent `trading_days_one_open_per_store`
   already set: SQL Prisma's schema DSL cannot express stays SQL-only, permanently "invisible" to
   `prisma migrate dev`'s own drift detection but real and applied via `migrate deploy` regardless —
   an accepted, documented convention in this codebase, not a new one invented here.

## Definition of Done

- [x] `apps/web/prisma/migrations/20260825183908_add_products_trgm_search_index/migration.sql` (new).
- [x] `docs/07-database/schema-server.md` — both indexes documented as built, replacing the prior
      "correctly re-scoped, left unbuilt" note.
- [x] Verified locally: `lint`/`typecheck` clean, `test` 227/227 (no application code touched, so
      this mainly confirms nothing else regressed), `prisma generate` succeeds.
- [x] Verified in CI: `fast-integration`'s `prisma migrate deploy` step applies the migration against
      a real ephemeral `postgres:15` container — the only way to actually confirm `pg_trgm` is
      available in that image and the `CREATE EXTENSION`/`CREATE INDEX` statements run cleanly.
- [x] `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md` updated in the
      same PR.
- [x] `sale_line_items.hsn_sac_code_at_sale` is now the only item remaining from Sprint 69's original
      four-index-plus-one-column finding list.

## Demo script

**Local/CI, run 2026-08-26:**

1. Confirmed `listProducts`'s actual search shape once more before writing the migration —
   `contains`/`insensitive` on `name` OR `sku`, unchanged since Sprint 70's own finding. ✅
2. Matched the migration's SQL style and hand-edited-outside-Prisma convention exactly against
   `trading_days_one_open_per_store`'s existing precedent. ✅
3. `prisma generate` — succeeded (schema.prisma itself unchanged). ✅
4. `lint`/`typecheck`/`test` — clean/clean/227/227. ✅
5. CI's `fast-integration` — `prisma migrate deploy` applied the new migration against a real
   `postgres:15` container, confirming `pg_trgm` is actually available there. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Sprints 69/70/72 together are a complete example of this session's own standing discipline applied to
itself across three consecutive passes: a documentation audit named a gap without fully verifying it
(69), a fix sprint caught and corrected one of those findings before building anything (70), and a
third sprint finally closed the remaining real one properly once the actual mechanism (`pg_trgm`, not
a plain B-tree) was correctly identified. Worth stating plainly: naming a gap, verifying a gap, and
fixing a gap are three separate steps, and skipping straight from "documented" to "fixed" — the
temptation Sprint 66 first named as the reason to re-check a prior session's own diagnosis — is
exactly what would have produced a real but useless index here.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-26 | Sprint 72: built `pg_trgm` trigram GIN indexes on `products.name`/`sku`, the real fix for the text-search gap Sprint 70 correctly re-scoped rather than built with the wrong tool. Hand-edited migration (Prisma's schema DSL has no operator-class syntax), matching the `trading_days_one_open_per_store` convention. No application-code change. `lint`/`typecheck`/`test` (227/227) verified clean; `fast-integration` verified in CI, confirming `pg_trgm` is available in the standard `postgres:15` image. Only `sale_line_items.hsn_sac_code_at_sale` remains from Sprint 69's original findings. |
