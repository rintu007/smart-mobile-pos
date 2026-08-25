# Sprint 73

> **Dates:** 2026-08-26 (single-day)
> **Milestone:** none — the last real fix from Sprint 69's own audit, not milestone work
> **Status:** Closed.

## Goal

Sprint 69's Phase 07 audit named `sale_line_items.hsn_sac_code_at_sale` as documented but never
built — a feature-shaped gap distinct from the four index gaps Sprints 70/72 already closed, since
it needs a new column plus real snapshot logic in the sale-creation path, not just an index. This
sprint closes it, completing every real, buildable finding that audit produced.

## What was built

`sale_line_items.hsn_sac_code_at_sale` (nullable `TEXT`), migration
`20260825185330_add_sale_line_item_hsn_sac_code_snapshot`. `pos/service.ts#createSale` now
snapshots `product.hsnSacCode` onto each line item at the moment it's priced — the identical pattern
`tax_registration_type_at_sale` (Sprint 28) already established for `shop_settings.tax_mode`: never
a live join, so a product's HSN/SAC code changing later can never alter an already-completed sale's
own historical line. `formatSale` exposes it additively as `hsn_sac_code_at_sale` on every line item,
reaching `GET /sales/{id}`, `GET /sales/lookup`, `POST /sales`'s own response, and `GET /sync/pull`'s
`sales` entity type — all four already-established consumers of `formatSale`'s shared shape, none of
which needed their own change.

## Design decisions

1. **Snapshot at sale-creation time, in `pos/service.ts`'s existing `lineItems.map`, not as a
   separate step.** The function already reads each line's `product` row to compute price/tax; the
   HSN/SAC snapshot is one more field read from data already in hand, not a new query.
2. **Nullable, not required.** Mirrors `products.hsn_sac_code`'s own nullability exactly — FR-033
   already decided a missing HSN/SAC code is flagged, not blocked, at the product level; a sale of
   such a product snapshotting `null` is the correct, honest continuation of that same policy, not a
   new validation gap to invent.
3. **No invoice-document change.** RR-003 needs the *number* stored per line; FR-055/FR-056's actual
   GST invoice rendering (GSTIN, the HSN/SAC breakup as a printed/displayed line, Bill-of-Supply vs.
   Tax-Invoice layout) is unchanged, still deferred to Receipt & Printing — matching Sprint 28's own
   explicit "computes the numbers, not the document" framing when tax computation itself was built,
   reused here rather than re-derived.
4. **Fixed two other stale claims in `pos/specification.md` while already in that section.** Its own
   `sales` table note still said `customer_id`/`device_id` were both "not yet built" — `customer_id`
   was built Sprint 32, and `device_id` was never actually part of the real design at all (Sprint 69's
   own `schema-server.md` correction). Left uncorrected, it would have kept implying `device_id` was
   still coming.

## Definition of Done

- [x] `apps/web/prisma/schema.prisma` — `SaleLineItem.hsnSacCodeAtSale` (nullable `String`).
- [x] `apps/web/prisma/migrations/20260825185330_add_sale_line_item_hsn_sac_code_snapshot/migration.sql`
      (new) — a single additive `ALTER TABLE ... ADD COLUMN`.
- [x] `pos/repository.ts` — `CreateSaleInput.lineItems[]` and the `tx.sale.create` write both carry
      the new field through.
- [x] `pos/service.ts` — `createSale`'s line-item construction snapshots `product.hsnSacCode`;
      `formatSale`'s type signature and output both expose `hsn_sac_code_at_sale`.
- [x] `apps/web/src/modules/pos/service.test.ts` (2 new cases): a product with a real HSN/SAC code
      snapshots it onto the line item; a product without one snapshots `null`.
- [x] Verified: `lint`/`typecheck` clean, `test` 229/229 (227 pre-existing + 2 new), `prisma
      generate && build` (CI-style placeholder env vars) succeeds.
- [x] `docs/07-database/schema-server.md`, `docs/modules/pos/specification.md` (also fixing the
      stale `customer_id`/`device_id` note), `implementation-log.md`, `docs/18-implementation/README.md`,
      `docs/README.md` all updated in the same PR.
- [x] Verified in CI: `fast-integration`'s `prisma migrate deploy` against a real ephemeral Postgres.
- [x] Every real, buildable finding from Sprint 69's original audit is now closed.

## Demo script

**Local/CI, run 2026-08-26:**

1. Traced every caller of `formatSale` (`pos/service.ts`, `sales-invoices/service.ts`,
   `sync/service.ts`) before writing any code, confirming all three pass real Prisma-typed `Sale`
   rows through directly — none needed their own change once the schema/service-layer change landed. ✅
2. `prisma generate` — succeeded against the updated schema. ✅
3. `pnpm --filter @smart-pos/web lint`/`typecheck` — both clean. ✅
4. `pnpm --filter @smart-pos/web test` — 229/229 (227 pre-existing + 2 new), including a case
   proving the snapshot survives independently of the product row (the test asserts on what
   `repository.createSale` was actually *called with*, not merely on a mocked return value). ✅
5. `prisma generate && build` with CI's own placeholder env vars — succeeded. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
This closes the arc Sprints 69/70/72/73 form together: one audit (69) surfaced five real gaps across
two categories — pure documentation drift (fixed directly in 69) and genuinely unbuilt functionality
(four indexes, one column). The unbuilt-functionality gaps were then closed as their own focused
sprints, each re-verified against live code before being built (70 caught one of the four index
findings was itself wrong; 72 built the index fix that actually works; this sprint closes the
remaining column). Four sprints, one originating audit, nothing left unaddressed or silently
dropped — the shape this project's own standing practice has aimed for since Sprint 43 first started
naming gaps explicitly rather than letting them sit unexamined.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-26 | Sprint 73: built `sale_line_items.hsn_sac_code_at_sale`, the last real gap from Sprint 69's audit. `pos/service.ts#createSale` snapshots `product.hsnSacCode` at sale-creation time, the same never-a-live-join pattern `tax_registration_type_at_sale` already established. Nullable, mirroring `products.hsn_sac_code`. `formatSale` exposes it additively — all existing consumers unaffected. Also fixed a stale `pos/specification.md` claim (`customer_id`/`device_id` both wrongly described as "not yet built"). `lint`/`typecheck`/`test` (229/229, 2 new) verified clean locally; `fast-integration` verified in CI. Invoice-document rendering (FR-055/056) remains deferred to Receipt & Printing, unchanged. Every real, buildable finding from Sprint 69's original audit is now closed. |
