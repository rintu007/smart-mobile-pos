# Sprint 19

> **Dates:** 2026-08-14 – 2026-08-14 (single-day, same cadence as every prior sprint)
> **Milestone:** M1 — Full Catalogue & Inventory, Multi-Role (backlog item 3)
> **Status:** Closed

## Goal

Extend `POST /api/v1/products` with `category_id`, `unit_id`, `sku`, `barcode`, `hsn_sac_code` —
the prerequisite Categories (Sprint 17) and Units (Sprint 18) unblocked. See
[products/specification.md §1](../modules/products/specification.md#1-purpose-and-business-context)
for a dated correction found while planning this sprint: the fields ship optional, not required as
backlog.md item 3 originally said (real production data and mobile's own current shape made
"required" the wrong call to ship today — details there, not repeated here).

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Extend `products`: `category_id`/`unit_id` (optional FK, existence-validated), `sku`/`barcode`/`hsn_sac_code` (optional, `sku`/`barcode` unique per tenant) | Products | 1.5 | Categories, Units |

Backend-only. No mobile change — mobile's `/catalogue/add` and its sync-push payload are
unaffected, by design (§1's own correction).

## Capacity check

1.5 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: `products/specification.md` (dated correction),
      `catalogue.md`/`error-catalogue.md` (`SKU_ALREADY_ASSIGNED`), backlog.md, module registry,
      implementation-log, README bumps.

## Risks

- **Real production data check, done before writing any code:** queried the live database first —
  4 real products already exist (from Sprint 16's own founder-run E2E proof) with no
  category/unit. This is what made "required" the wrong call this sprint, not a guess.
- **Regression risk:** mobile's `/catalogue/add` and the sync engine's `product.create` push both
  still send the original `{id, name, price_minor_units}` shape. Explicitly verified live as
  check #1 in this sprint's demo script, precisely because it's the scenario most likely to
  silently break.

## Definition of Done

- [x] `products/specification.md` updated with a dated correction (§1), §3/§4/§5/§6/§10/§11 revised
      to match, version 0.4.0.
- [x] `products` table extended: `category_id`, `unit_id` (nullable FK, `ON DELETE RESTRICT`),
      `sku`, `barcode` (each unique per tenant), `hsn_sac_code` — migration applied to the live
      Supabase database.
- [x] `POST /api/v1/products` accepts all five as optional; `category_id`/`unit_id` validated to
      exist under the caller's own tenant (`NOT_FOUND` otherwise); `barcode`/`sku` collisions
      return `BARCODE_ALREADY_ASSIGNED`/`SKU_ALREADY_ASSIGNED` (409).
- [x] `SKU_ALREADY_ASSIGNED` added to `catalogue.md` and `error-catalogue.md` in this PR.
- [x] Unit tests for the service layer (valid category/unit passthrough, not-found rejection for
      each, barcode/sku conflict translation, legacy-shape response still returns null fields).
- [x] `tsc --noEmit` / `eslint` clean.
- [x] Live verification against the real database, throwaway tenants deleted after — 9 checks
      including the legacy-shape regression check and a cross-tenant `NOT_FOUND` proof.
- [x] No secret, token, or key written to logs or committed to source.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** making `category_id`/`unit_id` required, `GET`/
`PATCH`/`DELETE /products`, barcode/SKU search (backlog item 5), mobile catalogue UI (item 4).

## Demo script

**Run 2026-08-14** against the live database, via real HTTP requests to a local dev server pointed
at production Supabase, throwaway tenants deleted after:

1. `POST /api/v1/products` with only `{id, name, price_minor_units}` (mobile's exact current
   shape) — `201`, `category_id`/`unit_id`/`sku`/`barcode`/`hsn_sac_code` all `null`. ✅
2. `POST /api/v1/products` with a real `category_id`/`unit_id`/`sku`/`barcode`/`hsn_sac_code` —
   `201`, all fields correct. ✅
3. Replay the identical full-shape request — same row, not a duplicate. ✅
4. A non-existent `category_id` — `404 NOT_FOUND`. ✅
5. A non-existent `unit_id` — `404 NOT_FOUND`. ✅
6. Tenant B given tenant A's real `category_id` — `404 NOT_FOUND` (tenant-scoped, not a leak). ✅
7. A second product with the same `barcode` in the same tenant — `409 BARCODE_ALREADY_ASSIGNED`. ✅
8. A second product with the same `sku` in the same tenant — `409 SKU_ALREADY_ASSIGNED`. ✅
9. The same `barcode` accepted for a *different* tenant — `201` (uniqueness is per-tenant). ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the first M1 sprint
whose own backlog wording ("required, FK") turned out to be wrong on contact with real production
data, rather than a gap this project found by *not* having built something yet. The check that
caught it — querying the live database before writing code, not after — is the same discipline this
project's "real HTTP request required" rule already enforces for endpoints; worth applying to
schema-change sprints as a standing habit, not just this one.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | Sprint 19 planned and built same-day: `products` extended with `category_id`/`unit_id`/`sku`/`barcode`/`hsn_sac_code`, all optional per a dated correction found against real production data before writing code. Live-verified — 9/9 checks, no new bug, legacy mobile shape confirmed unaffected. |
