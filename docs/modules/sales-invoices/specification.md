# Module Specification — Sales & Invoices

> **Status:** 🟢 Approved
> **Module:** Sales & Invoices
> **Slice:** V1 — Sprint 10's local-only mobile slice, plus Sprint 24's canonical invoice numbers
> and `GET /sales*` server endpoints; GST invoice fields remain M2 scope (§1)
> **Version:** 0.2.0
> **Last updated:** 2026-08-14
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 10](../../17-sprints/sprint-10.md); updated to drive
[Sprint 24](../../17-sprints/sprint-24.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

Lets a Cashier see the sales this device has completed. [dependency-graph.md](../../16-milestones/dependency-graph.md)
already places "POS core loop → Sales & Invoices → Receipt" as the next genuinely sequential step
once the till screen exists (Sprint 09) — this document is that next step's minimal cut, triggered
directly by the founder's own first hands-on test of the till screen surfacing the gap immediately
("it works fine, but no sell history").

**Sprint 10's deliberately narrow scope (unchanged, still true):** local-only, this-device's-own
sales list/detail, read straight from the local Drift tables the till screen already writes. No
network call, no new local table, no write path.

**This version (Sprint 24, [backlog.md item 8](../../17-sprints/backlog.md#2-m1--fully-decomposed-2026-08-14-now-that-m0-has-reached-this-point)):**
builds the two pieces of the full V1 shape that don't actually depend on tax computation —
canonical server-assigned invoice numbers ([ADR-0008](../../adr/ADR-0008-offline-invoice-numbering.md),
FR-058) and the `GET /sales*` server endpoints already documented in
[sales.md](../../11-api/endpoints/sales.md) — plus permission enforcement on all of it, per
[roles-permissions/specification.md](../roles-permissions/specification.md). **GST-compliant
invoice fields (FR-055/FR-056) remain out of scope**, exactly as backlog.md's own item 8 entry
already flagged: `sales`/`sale_line_items` have no tax/discount columns at all yet (M0's minimal
slice never added them — see [pos/specification.md §3](../pos/specification.md#3-database-tables-and-relationships)),
and tax computation itself is M2 scope. Adding GST fields without real tax computation behind them
would be exactly the kind of half-built feature this project's "no placeholders" rule exists to
prevent — named here as still-deferred, not silently dropped.

**A real, dated clarification found while writing this spec:** [sales.md](../../11-api/endpoints/sales.md)'s
own worked example shows `"canonical_invoice_number": null` in the `POST /sales` response, framed
as "null until assigned at sync." In this codebase's actual implementation, **a sale row is never
stored on the server at all until the moment it "arrives"** — `POST /sales` and `POST /sync/push`'s
`sale.create` operation both call the exact same `pos/service.ts#createSale`, so a queued-offline
sale's provisional-only, not-yet-synced state exists only on the mobile device's own local Drift
database (§7), never as a partial server row. By the time any `sales` row exists on the server at
all, it is already "arriving," so the canonical number is assigned in the same transaction as the
row's own creation — **`canonical_invoice_number` is never actually null for a stored sale**, a
stronger guarantee than the nullable column (matching schema-server.md exactly) suggests. The
column stays nullable to match the approved schema design and as a safety margin for a future state
this implementation doesn't currently produce, not because any code path leaves it unset.

## 2. Business rules

- A sale, once completed, is immutable — already true by construction (no update/delete code path
  exists anywhere in the app for `sales`/`sale_line_items`/`sale_payments`), which is how
  [FR-053](../../03-functional-requirements/functional-requirements.md) is satisfied: not by an
  enforced constraint, but by the simple fact that nothing has ever been built that could violate
  it. Unchanged this sprint.
- The mobile list shows only sales with `status = 'completed'` ordered most-recent-first by
  `completed_at`; a sale's line items are shown by joining against the local `products` cache,
  falling back to the raw `product_id` if a product is ever missing from it. Unchanged this sprint.
- **[ADR-0008](../../adr/ADR-0008-offline-invoice-numbering.md)'s canonical half, built this
  sprint:** every sale gains a `canonical_invoice_number` — a plain sequential integer, scoped to
  `(tenant_id, financial_year)`, assigned atomically in the *same transaction* as the sale's own
  creation via a dedicated `invoice_sequences` counter row (`UPDATE ... SET next_value =
  next_value + 1`, an ordinary Prisma `upsert` with `increment`, relying on Postgres's own
  row-level locking for atomicity under concurrent writers — no `SELECT ... FOR UPDATE` needed).
  Gapless by construction: the counter only advances when the sale itself actually commits: if the
  transaction rolls back for any reason, the counter's own increment rolls back with it.
- **Idempotent replay does not double-assign.** `pos/service.ts#createSale`'s existing
  `findSaleById` short-circuit (proven since Sprint 05) means `repository.createSale` — and the
  counter increment inside it — never runs a second time for the same sale `id`; a replayed sync
  push of an already-accepted `sale.create` operation returns the original sale, original canonical
  number, untouched counter. This is exactly [ADR-0008](../../adr/ADR-0008-offline-invoice-numbering.md)'s
  own compliance test ("replaying a sync of the same sale twice must not assign a second canonical
  number"), verified live (§10).
- `financial_year` is derived from `completed_at` at the moment of assignment — April 1 rollover,
  represented as the starting calendar year (e.g. `"2026"` for FY2026-27), the exact same string
  format mobile's own `InvoiceNumberGenerator._financialYearFor` already produces
  ([identifiers.md §3](../../07-database/identifiers.md#3-invoice-numbering--financial-year-rollover)).
  Since a server row only ever exists once it has "arrived," this is equivalent to sync-arrival
  time — identifiers.md §3's own stated rule ("assigned based on sync time, not sale time").
- `provisional_invoice_number` is now enforced unique per `(tenant_id)` at the database level — a
  real, pre-existing gap (M0 never added this constraint, despite
  [identifiers.md §2](../../07-database/identifiers.md#2-business-meaningful-identifiers-not-primary-keys)
  already documenting it as a business-meaningful identifier) closed in the same migration, since
  it costs nothing extra alongside the new canonical-number constraint.
- `GET /sales` is role-scoped, not just permission-gated: a **Cashier sees only sales they
  themselves created** (`created_by` = their own internal user id); **Manager and Owner see every
  sale, store-wide.** [sales.md](../../11-api/endpoints/sales.md)'s own documented Permission
  column says "Cashier (own device's trading day only)" — literally unimplementable, since neither
  `devices` nor `trading_days` exist in code (both continuing, separately-named gaps). "Own sales
  they personally rang up" is the closest faithful adaptation of that intent available with what
  actually exists — a named, dated interpretation, not silently invented. `GET /sales/{id}` and
  `GET /sales/lookup` carry no such restriction, matching their own table rows, which (unlike the
  list row) state no ownership qualifier at all.

## 3. Database tables and relationships

Mobile-local tables unchanged since Sprint 10 (§1).

**Server-side, built this sprint:**
- `sales` gains `canonical_invoice_number` (`BIGINT`, nullable — §1's dated clarification on why
  it's never actually null in practice) and `financial_year` (`TEXT`, nullable, same reasoning) —
  matching [schema-server.md](../../07-database/schema-server.md)'s documented `canonical_invoice_number`
  column exactly; `financial_year` is this implementation's own necessary supporting column
  (schema-server.md documents the *scoping dimension* but not a column to store it in — a
  reasonable, minimal addition, the same class of deviation `stock_movements.reason_code` already
  established in Sprint 22).
- New table `invoice_sequences` (`id`, `tenant_id`, `financial_year`, `next_value`) — the atomic
  counter backing canonical-number assignment. Not itself in schema-server.md's table list; ADR-0008
  explicitly leaves the mechanism open ("via a database sequence or an equivalent atomic counter"),
  and a per-tenant Postgres `SEQUENCE` object isn't practical for an unbounded number of tenants —
  a table-based counter is the standard, ADR-sanctioned equivalent.
- New constraints: `@@unique([tenantId, provisionalInvoiceNumber])` (closing a real, pre-existing
  gap — nothing enforced this before, despite identifiers.md already documenting it as a
  business-meaningful identifier) and `@@unique([tenantId, financialYear, canonicalInvoiceNumber])`
  (schema-server.md's own documented uniqueness scope). New index `(tenant_id, store_id,
  completed_at)` for the list endpoint (§4), replacing the plain `(tenant_id)` index it makes
  redundant.

RLS: `invoice_sequences` is tenant-scoped, same template as every other table
([supabase/sql/011_rls_invoice_sequences.sql](../../../supabase/sql/011_rls_invoice_sequences.sql)).
`sales`' own RLS is unchanged (already tenant-scoped since Sprint 05).

## 4. API contract

| Method & path | Status |
| --- | --- |
| `GET /api/v1/sales/{id}` | **Built this sprint.** Returns the sale with `line_items`/`payments` embedded, per [api-principles.md §2](../../11-api/api-principles.md#2-resource-naming). Any role, any sale in the tenant (§2). `404 NOT_FOUND` for an unknown or cross-tenant `id`. |
| `GET /api/v1/sales` | **Built this sprint.** Cursor-paginated on `(completed_at, id)`. Filters: `date_from`, `date_to` (both optional, ISO 8601). `trading_day_id`/`customer_id` from sales.md's original filter list are **not implemented** — neither Trading Day nor Customers exists in code yet, named continuing gaps, not silently dropped. Role-scoped per §2 (Cashier: own sales only; Manager/Owner: store-wide). Returns **summary fields only** — `id`, `status`, `provisional_invoice_number`, `canonical_invoice_number`, `financial_year`, `subtotal_minor_units`, `grand_total_minor_units`, `completed_at` — not nested `line_items`/`payments`, a deliberate design choice to keep a list response bounded regardless of how many line items each sale has; the `/{id}` detail endpoint is where the full embedded shape lives. |
| `GET /api/v1/sales/lookup` | **Built this sprint.** Exactly one of `provisional_invoice_number` or `canonical_invoice_number` (exact match) — Zod-refined to reject both-or-neither as `VALIDATION_FAILED`. Any role, any sale in the tenant. Returns the same detail shape as `GET /sales/{id}`. |
| `POST /api/v1/sales` | Unchanged request/response shape since Sprint 05/11/12. **Now also assigns `canonical_invoice_number`/`financial_year`** in the same transaction as the sale (§2) — response gains these two fields. |

**Route-file note, learned from Sprint 23's own live-found bug:** `GET /sales/lookup` and
`GET /sales/{id}` are separate static/dynamic siblings (`app/api/v1/sales/lookup/route.ts` vs.
`app/api/v1/sales/[id]/route.ts`) from the start — not discovered as a bug this time, applied
proactively because Sprint 23 already paid to learn it once.

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `cursor`/`limit` (`GET /sales`) | Same `.int().positive().max(200).default(50)` convention as every other list endpoint. |
| `date_from`/`date_to` (`GET /sales`) | Zod `.string().datetime().optional()`. |
| `provisional_invoice_number`/`canonical_invoice_number` (`GET /sales/lookup`) | Both optional individually; a Zod `.refine()` requires **exactly one** present — neither or both is `422 VALIDATION_FAILED`. |

## 6. Error handling and user-facing messages

No new error codes. `NOT_FOUND` (404) for an unknown/cross-tenant `id` on the detail endpoint or a
lookup with no match; `VALIDATION_FAILED` (422) for a malformed cursor or a lookup missing/carrying
both identifiers; `PERMISSION_DENIED` (403) is not actually reachable on any of the three new
endpoints, since every role is allowed to call them (§2) — only the *data returned* differs by role
for `GET /sales`, which is not a permission failure.

## 7. Offline behaviour

Mobile's own local list/detail (Sprint 10) is unchanged — fully offline, no server round-trip.
The three new server endpoints are **online-only, back-office/reporting capabilities with no
mobile consumer yet** — no mobile screen calls any of them this sprint, the same "documented,
tested, not yet consumed" position `GET /products` (Sprint 21) and `GET /stock-movements`
(Sprint 22) were both left in.

## 8. Realtime behaviour

None specified for V1 — no requirement found for live sale push to other devices; these are polled
reads, same as every other list/detail endpoint in this codebase.

## 9. UI specification

Unchanged since Sprint 10 (`/sales-history`, `/sales-history/:id`, mobile-local). **Now actually
enforced, not just a permission target**: any request to these mobile screens' own local data
still doesn't call the server at all (§7), so the route-map.md permission split
(Manager+ list, Cashier+ detail) remains a mobile-side UI concern that this sprint's server-side
`requirePermission` work doesn't reach — named explicitly, since it could otherwise read as
"permission enforcement, item 8" having closed this too.

## 10. Test plan

**Sprint 10 scope (unchanged, still passing):** see the original widget/unit tests, unaffected by
this sprint's server-only changes.

**Sprint 24 scope:**
- Unit tests (`pos/service.test.ts`, extended): `createSale`'s response includes
  `canonical_invoice_number`/`financial_year` from the repository's return value.
- Unit tests (`sales-invoices/service.test.ts`, new): role-scoped list filtering (Cashier passes
  `createdBy`, Manager/Owner don't); peek-and-trim pagination; date filter pass-through; malformed
  cursor rejected; lookup rejects both-or-neither identifiers; lookup/detail `NOT_FOUND` for a
  missing sale.
- **Live verification, real database, throwaway tenants (deleted after):**
  1. Two sales created back-to-back → sequential `canonical_invoice_number` (`1`, then `2`),
     same `financial_year`.
  2. Replaying the identical `POST /sales` request (same `id`) → still the original canonical
     number, counter not advanced a second time — ADR-0008's own compliance test.
  3. A second tenant's first sale → `canonical_invoice_number = 1` again — confirms the counter is
     genuinely per-tenant, not global.
  4. `GET /sales/{id}` → returns the sale with `line_items`/`payments` embedded.
  5. `GET /sales/lookup?canonical_invoice_number=1` and `?provisional_invoice_number=...` both
     resolve to the same sale; a request with both params → `422 VALIDATION_FAILED`.
  6. `GET /sales` as a Cashier who created 1 of 3 tenant sales → exactly 1 result; as the tenant's
     Owner → all 3.
  7. Cross-tenant RLS: tenant B's session reads zero of tenant A's `sales`/`invoice_sequences` rows.

**Explicitly deferred:** GST invoice fields (FR-055/FR-056, M2), a correction/void flow (FR-054),
cross-device sales visibility beyond what `GET /sales` already provides, receipt printing/sharing
(a separate module), any mobile UI consuming these new endpoints.

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [FR-053](../../03-functional-requirements/functional-requirements.md) (no operation can modify a completed sale) | §2 | Met — by construction, no write path exists |
| [FR-054](../../03-functional-requirements/functional-requirements.md) (a correction is a new record referencing the original) | — | **Not met** — no correction/void flow exists yet |
| [FR-055](../../03-functional-requirements/functional-requirements.md)–[FR-056](../../03-functional-requirements/functional-requirements.md) (GST invoice fields, Bill of Supply) | — | **Not met** — tax module doesn't exist (M2 scope), named again in §1 |
| [FR-057](../../03-functional-requirements/functional-requirements.md) (provisional invoice number generated offline) | — | Met, Sprint 09 |
| [FR-058](../../03-functional-requirements/functional-requirements.md) (provisional number preserved permanently, canonical attached at sync) | §2, §10 | **Met this sprint** — canonical numbers now assigned atomically, live-verified including the idempotent-replay proof |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-12 | First version — written to drive Sprint 10's minimal local-only sales list/detail, prompted directly by the founder's first hands-on test of the till screen. Scope deliberately narrow: local read only, no server endpoints, no tax/canonical-numbering/permission enforcement. |
| 0.2.0 | 2026-08-14 | Sprint 24 (backlog item 8): canonical invoice numbers (`invoice_sequences`, atomic per-tenant-per-financial-year counter) and `GET /sales*` (detail, list, lookup) built and live-verified. GST invoice fields remain explicitly deferred (M2 — tax computation doesn't exist). Dated clarification: `canonical_invoice_number` is never actually null in this implementation, since a server row only ever exists once "arrived." `provisional_invoice_number` uniqueness (a pre-existing gap) closed in the same migration. |
