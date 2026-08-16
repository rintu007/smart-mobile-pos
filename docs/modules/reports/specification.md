# Module Specification — Reports

> **Status:** 🟢 Approved
> **Module:** Reports (core four)
> **Slice:** V1 — the four reports named in [milestones.md — M4](../../16-milestones/milestones.md#m4--reports-settings-and-release-readiness):
> daily sales, top products, stock value, low stock; mobile-only, local aggregation, no new server
> report endpoint
> **Version:** 0.1.0
> **Last updated:** 2026-08-16
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 37](../../17-sprints/sprint-37.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

[backlog.md M4 item 2](../../17-sprints/backlog.md#5-m4--fully-decomposed-2026-08-16-now-that-m3-has-reached-this-point):
the four reports [FR-071](../../03-functional-requirements/functional-requirements.md#group-j--reports-core-four)–[FR-074](../../03-functional-requirements/functional-requirements.md#group-j--reports-core-four)
name — daily sales, stock value, top products, low stock — all classified "Fully offline, computed
from locally synced data." [Sprint 36](../../17-sprints/sprint-36.md) (M4 item 1) built exactly the
pull capability this depends on: `stock_movements`/`sales` now sync to every device regardless of
which device created them. This item is therefore pure mobile UI plus local Drift aggregation
queries — no new server report endpoint exists or is needed.

**A real, blocking gap found while starting this item, not anticipated at decomposition time:**
[BR-024](../../02-business-requirements/business-requirements.md)/[BR-045](../../02-business-requirements/business-requirements.md)
require the low-stock report's threshold to be **"a configurable per-product or shop-wide low-stock
threshold"** — and no such field exists anywhere in this schema. Not on `products`, not on
`shop_settings`. Without it, FR-074 cannot be built as anything but a hardcoded, unconfigurable
constant, which fails BR-024's own acceptance bar outright rather than merely narrowing it. Resolved
here, the same way [DR-008](../../03-functional-requirements/business-rules.md)'s missing `tax_rate`
source was resolved at Sprint 25 (M2 item 1): a single, shop-wide `shop_settings.low_stock_
threshold_quantity` (default `5`, Owner-editable via the already-built `PATCH /settings`) — a real,
honest V1 simplification matching `tax_rate_basis_points`' own precedent, not per-product granularity
(deferred, named, matching that same precedent's own reasoning: proportionate to what this schema
already treats as shop-wide elsewhere, revisit if a real pilot shop's product mix makes one number
useless).

**A second real, chained gap:** `shop_settings` has never been synced to any device — it is documented
in [sync-api.md §6](../../11-api/sync-api.md#6-pull--getsyncpull) as a pull entity type but, like
`stock_movements`/`sales` before Sprint 36, was never implemented. The low-stock report needs its
threshold value **offline** (FR-074's own classification), so this item also adds `shop_settings` as
sync pull's fourth implemented entity type — trivial compared to Sprint 36's own work, since
`shop_settings` is exactly one row per tenant, no pagination needed at all.

**A third real gap, the one [sync-engine/specification.md v0.7.0](../sync-engine/specification.md#1-purpose-and-business-context)
named but left for this item to actually resolve:** Reports' Manager/Owner gate
([permission-matrix.md — Reports](../../05-personas/permission-matrix.md#reports)) has no server call
to enforce it against — every device already holds the same shop-wide `stock_movements`/`sales`/
`shop_settings` data regardless of role. This item is therefore **the first place in this codebase
that builds genuine client-side role-awareness**, closing the "no client-side role-awareness exists
anywhere in mobile" gap [returns/specification.md §9](../returns/specification.md#9-ui-specification)
first named at Sprint 34 and left open ever since. Resolved narrowly, reusing an existing
Manager/Owner-only endpoint (`GET /users?limit=1`) purely as a permission probe — not a new
capability, not a cached JWT claim (this project's DR-017/018 principle is that role is always
resolved fresh, server-side, never trusted from a stale client-side source; a probe result is used
here only to decide **UI visibility** of a menu item, never to authorize an action, so the stakes of a
momentarily-stale cached probe are cosmetic, not a security boundary). The probe result is persisted
locally (fail-closed default: hidden until the first successful confirmation) so a genuinely offline
Owner who has synced at least once still sees their own Reports menu — the same "Fully offline"
guarantee the reports themselves carry.

## 2. Business rules

- **FR-071 (daily sales):** today's total plus the trailing 7 days, computed from local `Sales`
  (`status = 'completed'`, grouped by the local device's calendar day from `completedAt`).
- **FR-072 (stock value):** `Σ(derived balance × price basis)` across every product. "Price basis"
  is `products.price_minor_units` — the only monetary field this schema carries on a product; no
  separate cost/wholesale-price field exists anywhere (checked, not assumed), so stock value is
  necessarily computed against selling price, a named simplification carried forward from the
  schema itself, not invented here.
- **FR-073 (top products):** ranked by quantity or value sold, over a user-selected date range,
  from local `SaleLineItems` joined to `Sales` (`status = 'completed'`, `completedAt` within range).
- **FR-074 (low stock):** every product whose derived balance is below
  `shop_settings.low_stock_threshold_quantity`, sorted by distance below threshold (furthest-under
  first) — [BR-045](../../02-business-requirements/business-requirements.md)'s own explicit ordering.
- **Derived balance**, every report: `Σ(stock_movements.quantity_delta)` per product, from the local
  `StockMovements` cache — the same definition [stock-ledger.md](../../07-database/stock-ledger.md)
  already fixes server-side ([ADR-0005](../../adr/ADR-0005-append-only-stock-ledger.md)), computed
  locally instead of via a network round trip, since Sprint 36 already keeps this cache current.
- **Manager/Owner only**, client-side gate (§1's third gap) — a Cashier never sees the Reports entry
  point at all; there is no in-screen 403 to fall back on (no network call backs the reports
  themselves), so the gate must be visibility, not an error state, unlike every other role-gated
  mobile screen this project has built so far.
- **`shop_settings.low_stock_threshold_quantity` pull is unfiltered by role** — every device receives
  it regardless of the calling user's role, the same reasoning `stock_movements`/`sales` pull already
  established (Sprint 36 §1's own note): the data itself carries no per-role sensitivity, only the
  *decision to surface a report about it* does.

## 3. Database tables and relationships

**Server:** `shop_settings` gains one column, `low_stock_threshold_quantity INTEGER NOT NULL DEFAULT
5` — new migration, no RLS change (existing table, existing policy already covers every column).
`identity/repository.ts`'s onboarding transaction writes `5` for every newly-onboarded tenant,
matching every other Sprint 25 default's own "safest universal default" framing.

**Mobile:** one new table, `ShopSettingsCache` — schema v7→v8, non-destructive. A single row, literal
id `'current'`, matching `StoreContext`'s own established one-row-cache convention:

| Column | Purpose |
| --- | --- |
| `id` | Always `'current'` |
| `lowStockThresholdQuantity` | Pulled from `shop_settings` via the new sync entity type |
| `canViewReports` | The role-probe result (§1's third gap) — **not** pulled from any endpoint; written directly by `SyncRepository` after probing `GET /users?limit=1`, defaults to `false` until the first successful probe |
| `fetchedAt` | When either field was last refreshed |

Deliberately not a full `shop_settings` cache (no `tax_mode`/`pricing_mode`/`currency_code`/etc.) —
only the one field this item's reports actually need. Extended when Settings' mobile UI (M4 item 3)
needs the rest, not spoken for in advance.

## 4. API contract

| Method & path | Status |
| --- | --- |
| `GET /api/v1/sync/pull?entity_type=shop_settings` | **Built this sprint.** No cursor pagination — always returns the caller's tenant's single row (or an empty `data` array for the theoretical case of a pre-Sprint-25 tenant with none), `next_cursor`/`has_more` always `null`/`false`. Response: `{ data: [{ low_stock_threshold_quantity }], next_cursor: null, has_more: false }` — deliberately minimal, not the full `GET /settings` shape (§3's own "only what's needed" scoping). Any active role (same reasoning every other pull entity type already established). |
| `PATCH /api/v1/settings` | **Extended this sprint.** Gains `low_stock_threshold_quantity` (optional, `.int().min(0)`) to the already-existing partial-update body — Owner only, unchanged permission. |
| `GET /api/v1/users?limit=1` | **Reused, not extended** — already Manager/Owner-only (Sprint 23). This item is its first caller purely as a permission probe; the response body itself is discarded. |
| Reports themselves | **No new endpoint.** Every figure is computed on-device from already-synced local tables — see §2. |

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `low_stock_threshold_quantity` (`PATCH /settings`) | `.int().min(0)`, optional (partial update, same shape every other settings field already uses) |
| `entity_type=shop_settings` (pull) | No new query-param shape — reuses `syncPullQuerySchema`'s existing `cursor`/`limit`, both accepted but functionally inert for this entity type (a single row never needs paging) |

## 6. Error handling and user-facing messages

No new error codes. `GET /sync/pull?entity_type=shop_settings` and the `GET /users?limit=1` probe
both use existing, already-documented codes (`VALIDATION_FAILED`, `PERMISSION_DENIED`). The probe's
`PERMISSION_DENIED` (a Cashier's expected, normal case) is caught and swallowed inside
`SyncRepository` — never surfaced to the user, the same "swallow to a safe default" precedent
`pendingApprovalsCountProvider`/`pendingConflictsCountProvider` already established (Sprint 34/35).
The reports themselves have no error states beyond Flutter's own empty-state handling (an empty list
where nothing has synced yet is not an error, it is the correct empty answer).

## 7. Offline behaviour

Every report computes entirely from local Drift tables, no network call at report-view time — FR-071–074's
own "Fully offline" classification, satisfied by construction once `stock_movements`/`sales`/
`shop_settings` are cached (Sprint 36 plus this sprint's `shop_settings` addition). The one narrow,
named exception: a device that has **never once been online** cannot yet know whether it should show
the Reports menu at all (`canViewReports` defaults to `false`, fail-closed) — a real, accepted gap for
the true first-launch-offline case, judged acceptable since every device must complete at least one
online sign-in before it has any local data to report on in the first place.

## 8. Realtime behaviour

None — matching every other report/read-cache feature in this project. A report reflects whatever the
device last successfully synced, refreshed on the next sync cycle like everything else.

## 9. UI specification

- `/reports` — a hub screen (`ReportsScreen`), four tiles/list entries linking to each report.
  Visible only when `canViewReportsProvider` resolves `true` — the Reports entry point on
  `HomeScreen` itself is conditionally rendered, not merely disabled, matching §1's "visibility, not
  an error state" design decision.
- `/reports/daily-sales` — today's total, a simple 7-day list (date + total).
- `/reports/top-products` — a date-range picker (defaulting to the last 7 days) plus a sort toggle
  (quantity vs. value), a ranked list.
- `/reports/stock-value` — one total figure plus a per-product breakdown list.
- `/reports/low-stock` — a list of products below threshold, sorted furthest-under-first, each row
  showing balance vs. threshold.

No new navigation-model.md tap-count budget entry — these are back-office screens, not till-facing
(the same category Categories/Units/Settings already sit in, exempt from the Till-specific budget per
[tap-count-audit.md](../../09-navigation/tap-count-audit.md)'s own scope).

## 10. Test plan

- Unit tests (`settings/service.test.ts`): `getSettings`/`updateSettings` both carry
  `low_stock_threshold_quantity` through unchanged from every existing test's own shape, plus a new
  case confirming a partial update touching only this field leaves every other field untouched.
- Unit tests (`sync/service.test.ts`): `pullShopSettings` returns the tenant's row wrapped in the
  standard envelope, `next_cursor`/`has_more` always `null`/`false`; a tenant with no row (a
  theoretical pre-Sprint-25 case) returns an empty `data` array rather than throwing.
- Repository tests (`reports_repository_test.dart`, real in-memory Drift database): daily sales
  totals sum only `completed` sales, correctly bucketed by day; stock value multiplies each
  product's derived balance by its price and sums; top products ranks correctly by both quantity and
  value, respects the date range boundary (inclusive start, exclusive-of-next-day end); low stock
  includes only products strictly below threshold, sorted furthest-under-first; a product with zero
  movements/sales is excluded from top-products/low-stock (not a false zero-row).
- Repository tests (`sync_repository_test.dart`): `_pullShopSettings` writes the threshold into
  `ShopSettingsCache`; the role probe writes `canViewReports` true on a successful `GET /users` call
  and false on any error (403 or otherwise), never throwing out of `syncNow()` itself.
- Widget tests: `ReportsScreen` (and its four children) render against a fake `ReportsRepository`,
  matching every other screen's "fake, not a mock" convention; `HomeScreen` shows/hides the Reports
  entry point based on a faked `canViewReportsProvider` override.
- **No live-HTTP verification this sprint** for the reports themselves — mobile-only, local
  aggregation, the same "no server-side change, `flutter analyze`/`flutter test` is the verification
  bar" position Sprint 30 (Hold/Resume) already established for a comparable mobile-only item. The
  server-side additions (`low_stock_threshold_quantity` column, `shop_settings` pull) **are**
  live-verified against the real database, since they are genuine server changes.

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [FR-071](../../03-functional-requirements/functional-requirements.md#group-j--reports-core-four) (daily sales) | §2, §9 | Met |
| [FR-072](../../03-functional-requirements/functional-requirements.md#group-j--reports-core-four) (stock value) | §2, §9 | Met, against price basis (no cost field exists) |
| [FR-073](../../03-functional-requirements/functional-requirements.md#group-j--reports-core-four) (top products) | §2, §9 | Met |
| [FR-074](../../03-functional-requirements/functional-requirements.md#group-j--reports-core-four) (low stock) | §2, §3, §9 | Met — the threshold now exists, configurable, shop-wide |
| [BR-024](../../02-business-requirements/business-requirements.md)/[BR-045](../../02-business-requirements/business-requirements.md) | §1, §3 | Met for shop-wide; per-product threshold explicitly deferred, named |
| [permission-matrix.md — Reports](../../05-personas/permission-matrix.md#reports) | §1, §2, §9 | Met — the first genuine client-side role gate in this codebase |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-16 | First version — written to drive Sprint 37's implementation of the four core reports (backlog.md M4 item 2). Three real gaps found and resolved in the same pass, before code: no low-stock threshold configuration existed anywhere (resolved as a shop-wide `shop_settings.low_stock_threshold_quantity`, matching `tax_rate_basis_points`' own V1-simplification precedent); `shop_settings` was never synced to any device despite being documented as a pull entity type since Phase 11 (resolved as sync pull's fourth implemented entity type, trivial — one row, no pagination); Reports' Manager/Owner gate has no server call to enforce it against, requiring this codebase's first genuine client-side role-awareness (resolved via a probe against the already-existing `GET /users` endpoint, cached locally, fail-closed). |
