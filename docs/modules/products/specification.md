# Module Specification — Products

> **Status:** 🟢 Approved
> **Module:** Products (Categories, Units, Products in [scope-and-release-slices.md](../../01-vision/scope-and-release-slices.md)'s
> business-scoping grouping; tracked as its own row in the [module registry](../README.md), per
> [mobile-structure.md](../../08-folder-structure/mobile-structure.md)'s own note that the two
> groupings are different, valid axes over the same modules)
> **Slice:** V1 — this document scopes only M0's minimal first cut, not the full V1 shape (§1)
> **Version:** 0.7.0
> **Last updated:** 2026-08-14
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 04](../../17-sprints/sprint-04.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

Lets a shop record what it sells. [backlog.md item 5](../../17-sprints/backlog.md#1-m0--walking-skeleton-fully-decomposed)
scoped M0 to **name and price only** — no category, unit, barcode, SKU, or HSN/SAC — because
Categories and Units were explicitly [M1 scope](../../17-sprints/backlog.md#2-m1--fully-decomposed-2026-08-14-now-that-m0-has-reached-this-point),
not M0. That gap is now half-closed: Sprint 19 (backlog item 3) adds `category_id`, `unit_id`,
`sku`, `barcode`, `hsn_sac_code` to `POST /api/v1/products`, now that both Categories (Sprint 17)
and Units (Sprint 18) exist for the first two to reference.

**Correction, found planning Sprint 19 (2026-08-14):** [FR-032](../../03-functional-requirements/functional-requirements.md)
requires category and unit as **required** fields, and backlog.md item 3's own wording says
"required, FK." This sprint does **not** make them required — they are accepted as optional
fields. Two real, concrete facts made "required" the wrong call to actually ship today, found by
querying the live production database before writing this sprint's code, not assumed:

1. **4 real products already exist in production** (created during Sprint 16's own founder-run,
   real-device M0 end-to-end proof) with no `category_id`/`unit_id` at all. A `NOT NULL` migration
   against a live table with existing rows either fails outright or needs a backfill this sprint
   has no authorised default value for (there is no "Uncategorised" category/unit concept in any
   approved design document).
2. **Mobile's `/catalogue/add` screen — the only place a human actually picks a category or
   unit — doesn't exist yet.** It's [backlog.md item 4](../../17-sprints/backlog.md#2-m1--fully-decomposed-2026-08-14-now-that-m0-has-reached-this-point),
   a later, separate sprint. Mobile still calls `POST /products` (both directly and via the sync
   engine's `product.create` push) with the original M0-minimal `{id, name, price_minor_units}`
   shape. Making these fields mandatory today would 422-reject the founder's own already-verified,
   real, working app on its very next product creation — a regression, not progress.

So this sprint closes [FR-033](../../03-functional-requirements/functional-requirements.md) (SKU/
barcode/HSN, always optional by that requirement's own wording) in full, and the **storage** half
of FR-032/FR-035 (the columns and FK validation exist and work), but the **required** half of
FR-032/FR-035 stays a named, open gap until backlog item 4 ships a UI that can actually supply
these values — at which point a follow-up sprint makes the columns `NOT NULL` (with a backfill
plan for whatever real rows exist by then). Named here rather than silently narrowed or silently
overridden, the same pattern this document's own §11 already used for M0's original gap.

## 2. Business rules

- A product belongs to exactly one tenant (`tenant_id`), never shared or copied across tenants.
- `price_minor_units` is a non-negative integer in minor currency units, never a decimal — per
  [ADR-0006](../../adr/ADR-0006-money-as-integer-minor-units.md).
- `name` is required, non-empty, max 200 characters — no other field is required at creation in M0
  (contrast with FR-032's full V1 requirement — see §1).
- Creation is idempotent on the client-generated `id` ([ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md)):
  replaying the same request with the same `id` returns the original row unchanged, never a
  duplicate or an error — same mechanism Sprint 02 already established for `POST /api/v1/onboarding`.
- **Permission-checked as of Sprint 23**: `POST /products` requires Manager/Owner, `GET /products`
  any role — exactly the "Manager, Owner"/"any role" split [catalogue.md](../../11-api/endpoints/catalogue.md)
  already documented, now enforced by the Route Handler's own `requirePermission` call, per
  [roles-permissions/specification.md](../roles-permissions/specification.md).

## 3. Database tables and relationships

`products`, per [schema-server.md](../../07-database/schema-server.md) Context 2 — as of Sprint 19,
this sprint's slice covers the table's **full** column list: `id`, `tenant_id`, `category_id`,
`unit_id`, `name`, `sku`, `barcode`, `hsn_sac_code`, `price_minor_units`, `deactivated_at`,
`created_at`, `updated_at`, `created_by`. The one deviation from schema-server.md's own design:
`category_id`/`unit_id` are `NULL`-able here, not `NOT NULL` — see §1's dated correction. `sku` and
`barcode` are each unique per tenant via a compound `(tenant_id, sku)`/`(tenant_id, barcode)`
index — Postgres treats multiple `NULL`s as distinct, so this permits any number of products with
no `sku`/`barcode` while still rejecting a real collision within one tenant.

RLS: tenant-scoped, same template as `stores`
([supabase/sql/003_rls_stores.sql](../../../supabase/sql/003_rls_stores.sql)) — `products` has a
`tenant_id` column, so no special-casing is needed (contrast with `tenants` itself). No RLS change
needed this sprint — the table's own policy already covers every column added.

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/products` | **Implemented.** Request: `{ id, name, price_minor_units, category_id?, unit_id?, sku?, barcode?, hsn_sac_code? }` — the last five added Sprint 19, all optional (§1's dated correction). Requires Manager/Owner (`requirePermission`, Sprint 23 — §2). A provided `category_id`/`unit_id` must reference a row under the same tenant (`NOT_FOUND` if not); `sku`/`barcode` are rejected with `SKU_ALREADY_ASSIGNED`/`BARCODE_ALREADY_ASSIGNED` (409) if another product in the same tenant already has it. **Extended Sprint 11:** gains an optional `initial_quantity`, producing an `opening` stock movement in the same transaction — see [inventory/specification.md](../inventory/specification.md). |
| `GET /api/v1/products` | **Implemented Sprint 21** (backlog item 5). Query params: `search` (matches `name`/`sku`, case-insensitive), `category_id` (exact), `barcode` (exact) — all optional and combinable. Cursor-paginated on `(updated_at, id)`, per [api-principles.md §4](../../11-api/api-principles.md#4-pagination--cursor-only). Requires any role (`requirePermission`, Sprint 23 — §2). **Not what the till's own barcode scan/search/category-filter call** — those resolve against the mobile local cache (§7, §9): this endpoint serves any future non-offline-critical consumer (e.g. a `/catalogue` list screen, not yet built). |
| `PATCH /products/{id}`, `DELETE /products/{id}` | **Already documented**, not yet implemented — deferred past this sprint. |

**Mobile local write path — built [Sprint 07](../../17-sprints/sprint-07.md).**
`apps/mobile/lib/features/catalogue/` (`DriftProductRepository.createProduct`) writes to the local
`products` table and enqueues a `product.create` operation to `outbound_queue` in a single Drift
transaction — payload identical to this table's request shape (`{ id, name, price_minor_units }`),
per [sync-api.md §1](../../11-api/sync-api.md#1-push--post-syncpush)'s "push does not define a
second, parallel request schema." Idempotent on `id`, same as the server endpoint. **Nothing yet
drains the queue** — the sync engine (backlog item 9) is a separate, later sprint; a product
created on-device stays local-only (never pushed to the server) until that sprint exists.

## 5. Validation rules (client and server)

Request body for `POST /api/v1/products` (Zod schema, server-side):

| Field | Rule |
| --- | --- |
| `id` | UUIDv4, required — client-generated per [ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md) |
| `name` | Non-empty string, required, max 200 chars |
| `price_minor_units` | Non-negative integer, required |
| `category_id` | UUIDv4, optional (§1) — must reference a category under the caller's own tenant |
| `unit_id` | UUIDv4, optional (§1) — must reference a unit under the caller's own tenant |
| `sku` | Non-empty string, optional, max 100 chars — unique per tenant |
| `barcode` | Non-empty string, optional, max 100 chars — unique per tenant |
| `hsn_sac_code` | Non-empty string, optional, max 20 chars — no format validation (FR-033 doesn't specify one) |

Query params for `GET /api/v1/products` (Sprint 21):

| Field | Rule |
| --- | --- |
| `search` | Non-empty string, optional, max 200 chars |
| `category_id` | UUIDv4, optional — no existence check (an unknown id simply matches nothing, same as any filter) |
| `barcode` | Non-empty string, optional, max 100 chars |
| `cursor`, `limit` | Same as every other cursor-paginated list endpoint (`api-principles.md §4`) |

## 6. Error handling and user-facing messages

`VALIDATION_FAILED` (422) for schema failures, per
[error-catalogue.md](../../11-api/error-catalogue.md). Added Sprint 19: `NOT_FOUND` (404) when a
provided `category_id`/`unit_id` doesn't resolve under the caller's tenant; `BARCODE_ALREADY_ASSIGNED`/
`SKU_ALREADY_ASSIGNED` (409) on a per-tenant uniqueness collision — the latter added to
[catalogue.md](../../11-api/endpoints/catalogue.md)/[error-catalogue.md](../../11-api/error-catalogue.md)
in the same PR as the sibling of the former, which already existed there. `GET /api/v1/products`
(Sprint 21) needs no new error code — a malformed `cursor` reuses the same `VALIDATION_FAILED`
every other cursor-paginated endpoint already returns. No user-facing copy specified here, same
reasoning as Company & Store Setup's spec §6 (backend-only sprint, no mobile screen yet).

## 7. Offline behaviour

The server endpoints themselves require connectivity, same as any `POST`/`GET` — but per
[catalogue.md](../../11-api/endpoints/catalogue.md), `POST /products` is documented as
**offline-capable** in the full V1 design (queued via `outbound_queue`, per
[sync-api.md](../../11-api/sync-api.md)'s "Products created offline" dependency-ordering note).
**Built Sprint 07**: creating a product on-device writes locally and enqueues immediately,
regardless of connectivity — the screen never calls the network directly. What's still missing is
the other half of "offline-capable": nothing yet drains the queue back to the server (backlog item
9, the sync engine), so a product created offline currently stays offline indefinitely rather than
eventually syncing — a real, named gap, not a claim that offline support is complete.

**`GET /api/v1/products` (Sprint 21) is a plain online-only endpoint** — nothing in this module
claims otherwise. FR-034 (search fallback for a barcode-less product) and FR-036 (category filter
on the POS grid) are both marked **"Fully offline"** in functional-requirements.md, and Sprint 21
meets that requirement a different way: the till screen's own search field, category chips, and
barcode-scan button (§9) resolve entirely against the mobile local `products`/`categories` cache,
never calling this endpoint. This also closes a real gap Sprint 20 left open, found while wiring
the barcode feature: the sync pull response never carried `category_id`/`unit_id`/`sku`/`barcode`
down to devices at all (only a product's own creating device ever had them locally) — fixed in the
same pass, in `sync/service.ts`'s `pullProducts` and the mobile pull-mapping.

## 8. Realtime behaviour

None specified for V1 (no requirement found for live product-list push to other devices in this
sprint's scope) — other devices see a new product via the next sync pull.

## 9. UI specification

`/catalogue/add` (added to [route-map.md](../../09-navigation/route-map.md) as a dated correction
during Sprint 07 planning — the original route list covered viewing/editing an existing product
but not creating one) — **built Sprint 07**
(`apps/mobile/lib/features/catalogue/presentation/screens/add_product_screen.dart`): name and price
fields, reached via a FAB on the app shell's home screen until the product list screen (`/catalogue`
itself) is built. No dedicated design-system composition spec exists for this screen (only the till
screen is composed in patterns.md), so it follows components.md §1/§2's generic button/text-field
states. The product **list** screen (`/catalogue`) itself is not yet built — this sprint only
built the add flow, reachable directly rather than through a list that doesn't exist yet.

**Extended Sprint 20** (backlog item 4): the screen gains two required dropdowns, Category and
Unit, sourced from the new [`/catalogue/categories`](../categories/specification.md#9-ui-specification)/
[`/catalogue/units`](../units/specification.md#9-ui-specification) local caches — form validation
rejects submission until both are selected. This is a **UI-level** requirement only
(`ProductRepository.createProduct`'s own docstring): the server's `POST /api/v1/products` still
accepts both as optional (§1's Sprint 19 correction). A tenant with zero categories/units shows an
empty dropdown with no way to proceed from this screen alone — the Manager is expected to visit
`/catalogue/categories`/`/catalogue/units` first (reachable from the home screen, same as
`/catalogue/add` itself); no inline "create one now" shortcut was built this sprint, a real, minor
UX gap named rather than silently absorbed.

**Extended Sprint 21** (backlog item 5, FR-034/FR-036): `/pos` (the till screen) gains a search
field (filters the loaded local product list by `name`, case-insensitive substring), category
filter chips (sourced from the same local `categoriesListProvider` `/catalogue/categories` already
built), and a "scan barcode" button opening a new `/pos/scan` route
(`apps/mobile/lib/features/pos/presentation/screens/barcode_scan_screen.dart`, a thin
`mobile_scanner` camera view — not itself unit/widget tested, the same untested-hardware-integration
boundary this project already drew for `printer_picker_dialog.dart`'s Bluetooth picker). A
successful scan looks the barcode up in the local `products` cache
(`ProductRepository.findByBarcode`) and adds the match to the cart directly, or shows an inline
"not found" message — all local, all synchronous with no network round trip, meeting FR-034/036's
"Fully offline" requirement and NFR-002's p95 latency budget by construction (there is no request to
wait on). `/pos/scan` itself was missing from [route-map.md](../../09-navigation/route-map.md)'s
original decomposition — added there as a dated correction, same shape as `/catalogue/add`'s own
Sprint 07 correction.

## 10. Test plan

**Sprint 21 scope:**
- Server unit tests: `GET /api/v1/products` — `search` matches `name`/`sku`; `category_id`/`barcode`
  filter exactly; peek-and-trim cursor pagination; malformed cursor rejected.
- **Real HTTP request required before this was marked done** — live-verified against the real
  database, throwaway tenants deleted after: `search` matching two products by name and one by
  `sku`; `category_id` filter; `barcode` exact match; a real two-page cursor walk; a cross-tenant
  scoping proof; malformed-cursor rejection — 7/7 checks, no new bug.
- Mobile unit tests: `DriftProductRepository.findByBarcode` (match and no-match cases);
  `SyncRepository` upserting a pulled product's `category_id`/`unit_id`/`sku`/`barcode` into the
  local cache (the Sprint 20 gap fix, §7); `sync/service.test.ts`'s `pullProducts` carrying the same
  four fields through the server response.
- Mobile widget tests: the till screen's search field filters the rendered list by name; the
  barcode-scan button renders and is wired to `findByBarcode` (the scan screen itself — real camera
  hardware — is not exercised, named in §9).
- `flutter analyze`/`flutter test` (94/94) and the web `vitest`/`tsc`/`eslint` suites all clean.

**Explicitly deferred:** a `/catalogue` product-list screen (the only mobile consumer that would
call `GET /api/v1/products` directly), `PATCH`/`DELETE /products`, making `category_id`/`unit_id`
required (§1).

**Sprint 19 scope:**
- Unit tests: `category_id`/`unit_id` provided and valid are stored and returned; either provided
  but not found under the caller's tenant rejects with `NOT_FOUND`; a repository-level unique-
  constraint violation on `barcode`/`sku` translates to `BARCODE_ALREADY_ASSIGNED`/
  `SKU_ALREADY_ASSIGNED`; omitting all five new fields still returns `201` with them `null` (the
  regression this sprint cares most about — mobile's existing shape must keep working).
- **Real HTTP request required before this was marked done** — same standing rule. Live-verified
  against the real database, throwaway tenants deleted after: the exact legacy
  `{id, name, price_minor_units}` shape still succeeds; a full-shape creation with a real
  category/unit/sku/barcode/hsn_sac_code; idempotent replay; `NOT_FOUND` for a missing
  category_id/unit_id, including a cross-tenant case (tenant B given tenant A's category_id);
  `BARCODE_ALREADY_ASSIGNED`/`SKU_ALREADY_ASSIGNED` on a same-tenant collision; the same barcode
  accepted for a *different* tenant (proving the uniqueness is per-tenant, not global).

**Explicitly deferred:** making `category_id`/`unit_id` required (§1), `GET`/`PATCH`/`DELETE
/products`, the product list screen, barcode/SKU search (backlog item 5), mobile's own
category/unit picker UI (backlog item 4).

**Sprint 04 scope:**
- Unit test: `POST /api/v1/products` creates exactly one `products` row with the given `id`,
  `name`, `price_minor_units`.
- Unit test: a retry with the identical `id` is a no-op (idempotent replay), same mechanism as
  onboarding.
- Unit test: validation rejects a missing `name`, a negative `price_minor_units`, and a malformed
  `id`.
- Cross-tenant negative test: tenant A's session cannot read tenant B's `products` row — requires
  RLS (§3), run live against the real database, same proof style as Sprint 02's `stores` test.
- **Real HTTP request required before this endpoint is marked done** — Sprint 02's addendum rule
  ([retrospective-log.md](../../17-sprints/retrospective-log.md)): a unit-tested, typechecked
  service is not the same claim as a working HTTP endpoint.

**Sprint 07 scope (mobile):**
- Repository test (`drift_product_repository_test.dart`): writes both the `products` row and the
  matching `outbound_queue` row; idempotent replay with the same `id` writes neither a second time;
  a forced enqueue failure leaves no `products` row behind (the transaction is atomic).
- Widget tests (`add_product_screen_test.dart`): empty/invalid-price validation, the loading state,
  and a thrown failure rendering as inline error text.
- **Live verification required before this was marked done** — same rule as Sprint 02's HTTP-request
  addendum, applied to local storage instead of a server: a real file-backed `NativeDatabase`
  (not `.memory()`) was written to, closed, and reopened on a fresh connection to prove the write
  actually persists to disk, not just within one open connection's cache.

**Explicitly deferred past Sprint 07:** `GET`/`PATCH`/`DELETE /products`, the product list screen
(`/catalogue`), the sync engine that would actually push a locally-created product to the server
(§7), everything FR-032/FR-035 require beyond name/price (§1).

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [FR-032](../../03-functional-requirements/functional-requirements.md) (name, price, unit, category required) | §5 | **Partially met** — the fields exist and are validated when provided, but are optional, not required (§1's dated correction) |
| [FR-033](../../03-functional-requirements/functional-requirements.md) (SKU/barcode/HSN optional) | §3, §5, §6 | Met |
| [FR-035](../../03-functional-requirements/functional-requirements.md) (every product belongs to exactly one category) | §3, §5 | **Not met** — `category_id` is optional, not required (§1); a product can still be created with none |
| [FR-034](../../03-functional-requirements/functional-requirements.md) (a product with no barcode remains addable via search) | §9 | Met — Sprint 21, till search field, local cache |
| [FR-036](../../03-functional-requirements/functional-requirements.md) (POS grid filterable by category) | §9 | Met — Sprint 21, till category filter chips, local cache |
| [NFR-002](../../03-functional-requirements/non-functional-requirements.md) (barcode scan → item on screen, p95 ≤ 800 ms) | §9 | Met by construction — the till's scan lookup is a local Drift query, no network round trip |
| [ADR-0006](../../adr/ADR-0006-money-as-integer-minor-units.md) (money as integer minor units) | §2 | Met |
| [ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md) (client-generated UUID PKs, idempotent creation) | §2, §5 | Met |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-01 | First version — written to drive Sprint 04's implementation of `POST /api/v1/products`. Scope deliberately narrow (name/price only); FR-032/FR-035's category/unit requirement and the mobile local write path both named as not-yet-met rather than silently claimed. |
| 0.2.0 | 2026-08-02 | Sprint 07: mobile local write path built (`DriftProductRepository`, `/catalogue/add`) — local write and `outbound_queue` enqueue atomic in one Drift transaction, idempotent on `id`, verified against a real on-disk file. Nothing yet drains the queue (sync engine, backlog item 9) — named explicitly, not claimed as full offline support. |
| 0.3.0 | 2026-08-13 | Sprint 11: `POST /api/v1/products` gains an optional `initial_quantity`, producing one `opening` stock movement in the same transaction as the product row — see [inventory/specification.md](../inventory/specification.md). Mobile still sends no `initial_quantity` (unchanged this sprint), so every mobile-created product gets a zero-quantity opening movement until a later sprint adds the field to `/catalogue/add`. |
| 0.4.0 | 2026-08-14 | Sprint 19 (backlog item 3): `category_id`/`unit_id`/`sku`/`barcode`/`hsn_sac_code` added to `POST /api/v1/products`, all optional — a deliberate, dated correction against backlog.md item 3's "required" wording, found by querying live production data before writing code: 4 real products already exist without these fields, and mobile can't supply them until backlog item 4's catalogue UI ships. Closes FR-033 in full; FR-032/FR-035's *required* half stays open, named, tracked to a follow-up sprint once item 4 exists. Added `SKU_ALREADY_ASSIGNED` alongside the pre-existing `BARCODE_ALREADY_ASSIGNED`. Live-verified: legacy shape still works (the regression check), full-shape creation, idempotent replay, `NOT_FOUND` for missing/cross-tenant category_id/unit_id, both uniqueness conflicts, per-tenant (not global) uniqueness — 9/9 checks, no new bug. |
| 0.5.0 | 2026-08-14 | Sprint 20 (backlog item 4): `/catalogue/add` extended with required Category/Unit dropdowns, sourced from the new mobile catalogue screens. A UI-level requirement only — the server endpoint itself stays optional (§1). Local `Products` table gains nullable `category_id`/`unit_id` columns; the `product.create` sync-push payload now carries real values, no backend change needed since Sprint 19 already accepts them. |
| 0.6.0 | 2026-08-14 | Sprint 21 (backlog item 5): `GET /api/v1/products` implemented (`search`/`category_id`/`barcode`, cursor-paginated), live-verified 7/7. Till screen gains a search field, category filter chips, and a barcode-scan button (FR-034/FR-036/NFR-002) — all resolved against the local cache, not this new endpoint, per those FRs' "Fully offline" classification. Found and fixed a real Sprint 20 gap: the sync pull response never carried `category_id`/`unit_id`/`sku`/`barcode` down to devices at all. `/pos/scan` added to route-map.md as a dated correction. `flutter test` 94/94. |
| 0.7.0 | 2026-08-14 | Sprint 23: permission enforcement applied — `POST /products` now requires Manager/Owner, `GET /products` any role, per [roles-permissions/specification.md](../roles-permissions/specification.md). |
