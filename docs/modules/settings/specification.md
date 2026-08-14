# Module Specification — Settings

> **Status:** 🟢 Approved
> **Module:** Settings
> **Slice:** V1, minimal — `shop_settings` table, a default row written at onboarding, `GET`/`PATCH
> /settings` with the role-shaped read scope [settings.md](../../11-api/endpoints/settings.md)
> already specifies (§1)
> **Version:** 0.1.1
> **Last updated:** 2026-08-14
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 25](../../17-sprints/sprint-25.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

[backlog.md M2 item 1](../../17-sprints/backlog.md#3-m2--fully-decomposed-2026-08-14-now-that-m1-has-reached-this-point):
"Settings, minimal slice... a default row written in the same onboarding transaction as
`tenants`/`stores`, `GET`/`PATCH /settings` with the role-shaped read scope settings.md already
specifies." This is the first item of M2 — Full POS Loop, and deliberately so: it is a
**prerequisite**, not a feature in its own right. Discount (M2 item 3) and Tax computation (M2 item
4) both need a real `shop_settings` row to read (an auto-approval threshold, a tax mode/rate), and
none exists in code today.

**The real gap this sprint closes, found while decomposing M2 (not by writing code first):**
[dependency-graph.md §4](../../16-milestones/dependency-graph.md#4-settings--a-configuration-input-not-a-graph-dependency)
states Settings' fields "simply need sensible defaults present from Setup onward" — true of the
*design*, but `identity/repository.ts`'s `createOnboarding` transaction has only ever written
`tenants`/`stores`/`users`/the bootstrap `user_store_roles` row (Sprint 23). No `shop_settings` row,
default or otherwise, has ever been created. Discount/Tax would otherwise be built against a table
with zero rows in it for every existing tenant.

**A second real gap, in the Phase 07 design itself:** [schema-server.md](../../07-database/schema-server.md)'s
`shop_settings` never actually named where [DR-008](../../03-functional-requirements/business-rules.md)'s
`tax_rate` comes from — only `tax_mode` (registration status) existed, no rate. Resolved as a dated
correction to `schema-server.md`/`money-and-tax.md` (2026-08-14, same day as this spec): a single
shop-wide `tax_rate_basis_points` column, applied uniformly to every line. Per-product/per-HSN slab
rates are named, deferred V2+ scope — see [money-and-tax.md §2a](../../07-database/money-and-tax.md#2a-where-tax_rate_basis_points-comes-from-correction-found-2026-08-14-decomposing-m2)
for the full reasoning.

**Deliberately still out of scope this sprint:**

- `printer_config`/`receipt_template_config` (both `JSONB`) — no printer-pairing flow or receipt-template
  editor exists yet (Receipt & Printing's own future scope), and `RECEIPT_TEMPLATE_MISSING_MANDATORY_FIELD`'s
  validation needs a mandatory-field list that isn't specified as code anywhere. Both columns are
  created (nullable, per schema-server.md) but `PATCH /settings` rejects any attempt to set either
  this sprint — the same "table exists, endpoint doesn't touch the field yet" shape Units'
  `allows_fractional` already established.
- Business-type-based default seeding ([seed-data.md](../../07-database/seed-data.md)'s per-vertical
  defaults, FR-002) — onboarding collects no business-type field today. This sprint uses
  seed-data.md's own named **"safest universal default"** instead (§3), not a per-vertical one.
- `SETTINGS_CHANGE_REQUIRES_CONNECTIVITY`'s offline exception (§7) — enforced client-side only, per
  settings.md's own note; nothing for this backend sprint to build beyond simply not offline-queuing
  the endpoint (it already isn't, by construction — `PATCH /settings` is not wired into
  `sync/push`'s operation-type union at all).

## 2. Business rules

- **One row per tenant, `tenant_id` as its own primary key** — [schema-server.md](../../07-database/schema-server.md)'s
  fixed design; no per-store settings exist in V1 even though [ADR-0003](../../adr/ADR-0003-multi-outlet-modelled-from-day-one.md)
  models multi-outlet from day one elsewhere. Not revisited here — a real, separate future decision if
  multi-outlet shops turn out to need per-store tax/rounding configuration.
- **Universal safe defaults, written at onboarding** (seed-data.md §"safest universal default" /
  own explicit values chosen this sprint, named here since seed-data.md doesn't fix a single number
  for the threshold fields): `tax_mode = 'unregistered'`, `tax_rate_basis_points = 0`,
  `pricing_mode = 'inclusive'` (India's dominant retail convention — MRP, tax-already-included shelf
  pricing — is the more common default than exclusive for the shop sizes this product targets; a
  genuine judgment call, not a documented Phase 07 decision, named here so it can be revisited),
  `rounding_rule = 'round_half_up'`, `currency_code = 'INR'` (schema default),
  `discount_auto_approval_threshold_minor_units = 50000` (₹500), `return_auto_approval_threshold_minor_units = 100000`
  (₹1,000) — both flat, universal starting points pending the business-type-based seeding
  seed-data.md actually specifies; an Owner can raise or lower either immediately via `PATCH
  /settings`.
- [DR-009](../../03-functional-requirements/business-rules.md): `tax_mode = 'composition'` or
  `'unregistered'` forces `tax_rate_basis_points` to `0` — enforced at the service layer on every
  `PATCH /settings` (setting a nonzero rate while not `'standard'` is rejected, not silently
  zeroed), not just read as a convention by the Tax module later.
- **`PATCH /settings` requires connectivity** — [settings.md](../../11-api/endpoints/settings.md)'s
  own already-documented exception to this API's general offline-first stance; restated here as
  this module's own rule, not re-derived.
- **Whole-row optimistic concurrency, never a field merge** — [conflict-resolution.md §4](../../13-offline-sync/conflict-resolution.md#4-the-one-deliberate-exception--shop_settings-does-not-field-merge)'s
  already-fixed policy. `PATCH /settings` requires the caller's `base_updated_at` to match the
  row's current `updated_at`; a mismatch rejects the whole request with `SETTINGS_CONFLICT` — the
  caller re-fetches and re-applies their intended change, never a partial/merged write.
- [DR-021](../../03-functional-requirements/business-rules.md): only an Owner may `PATCH /settings`
  — a Manager holds every Cashier permission plus discount/return approval and stock adjustment,
  but settings configuration is Owner-only, per [permission-matrix.md — Settings](../../05-personas/permission-matrix.md#settings).

## 3. Database tables and relationships

New table: `shop_settings`, matching [schema-server.md](../../07-database/schema-server.md)'s
documented shape plus this sprint's `tax_rate_basis_points` correction: `tenant_id` (PK, FK
`tenants(id)` `ON DELETE CASCADE`), `tax_mode`, `tax_rate_basis_points`, `pricing_mode`,
`rounding_rule`, `currency_code`, `discount_auto_approval_threshold_minor_units`,
`return_auto_approval_threshold_minor_units`, `printer_config` (nullable `JSONB`),
`receipt_template_config` (nullable `JSONB`), plus the standard `created_at`/`updated_at`/`created_by`
columns every Tier 1 table gets ([schema-server.md](../../07-database/schema-server.md)'s stated
convention). No `CHECK` constraints on `tax_mode`/`pricing_mode`/`rounding_rule` in the migration
itself — matching `stock_movements.movement_type`/`sales.status`'s own established precedent of
relying on application code (Zod) rather than a hand-edited migration.

`identity/repository.ts`'s `createOnboarding` transaction gains a fifth write: one `shop_settings`
row, `tenant_id` reused as the row's own natural key (no separate generated id needed, since this
table's PK already is `tenant_id`), populated with §2's universal defaults, `created_by =
input.user_id` — the same "reuse an existing id for a natural 1:1" pattern `user_store_roles`
already established for its own onboarding write.

RLS: tenant-scoped, same template as every other table
([supabase/sql/012_rls_shop_settings.sql](../../../supabase/sql/012_rls_shop_settings.sql)).

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/onboarding` | **Extended this sprint.** Now also creates one `shop_settings` row (§2's defaults) in the same transaction as the tenant/store/user/role rows. Request/response shape unchanged. |
| `GET /api/v1/settings` | **Built this sprint.** Any authenticated role. Returns a **role-shaped** response per [settings.md §"Field-level read scope"](../../11-api/endpoints/settings.md#field-level-read-scope): `tax_mode`/`tax_rate_basis_points`/`pricing_mode`/`rounding_rule`/`currency_code`/`printer_config`/`receipt_template_config` to everyone; `discount_auto_approval_threshold_minor_units`/`return_auto_approval_threshold_minor_units` omitted entirely (not merely zeroed) for a Cashier. |
| `PATCH /api/v1/settings` | **Built this sprint.** Owner only. Partial update — only fields present in the request body are changed. Requires `client_operation_id` (idempotency) and `base_updated_at` (optimistic concurrency, §2). Rejects `printer_config`/`receipt_template_config` if present in the body (§1 — deferred this sprint) with `VALIDATION_FAILED`, not silently ignored. |

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `client_operation_id` (PATCH) | UUID v4 — Zod `.uuid()`. |
| `base_updated_at` (PATCH) | ISO-8601 datetime string — Zod `.datetime()` — required on every `PATCH`, no partial-update exception. |
| `tax_mode` | Zod `.enum(["standard", "composition", "unregistered"])`, optional (partial update). |
| `tax_rate_basis_points` | `.int().min(0).max(10000)` (0–100.00%), optional. Cross-field rule: rejected with `TAX_RATE_REQUIRES_STANDARD_MODE` if the **resulting** `tax_mode` (from this request or the existing row) is not `'standard'` and the resulting rate is nonzero (§2). |
| `pricing_mode` | Zod `.enum(["inclusive", "exclusive"])`, optional. |
| `rounding_rule` | Zod `.enum(["round_half_up", "round_half_even"])`, optional. |
| `currency_code` | Zod `.string().length(3)`, optional — format-validated only; no ISO-4217 membership check this sprint (same "accept the shape, don't build the full reference table" scoping `hsn_sac_code` used). |
| `discount_auto_approval_threshold_minor_units`, `return_auto_approval_threshold_minor_units` | `.int().min(0)`, optional. |
| `printer_config`, `receipt_template_config` | **Rejected if present at all** — `VALIDATION_FAILED` (§1, §4). |

## 6. Error handling and user-facing messages

| Code | HTTP | Cause |
| --- | --- | --- |
| `PERMISSION_DENIED` | 403 | Already reserved (cross-cutting). `PATCH /settings` called by a non-Owner. |
| `SETTINGS_CONFLICT` | 409 | Already reserved ([settings.md](../../11-api/endpoints/settings.md)), implemented this sprint: `base_updated_at` doesn't match the row's current `updated_at`. |
| `TAX_RATE_REQUIRES_STANDARD_MODE` | 422 | **New.** A nonzero `tax_rate_basis_points` combined with a non-`'standard'` `tax_mode` (§5). |
| `VALIDATION_FAILED` | 422 | Any Zod failure, including an attempt to set `printer_config`/`receipt_template_config` this sprint. |
| `NOT_FOUND` | 404 | `GET`/`PATCH /settings` called for a tenant with no `shop_settings` row — should not occur for any tenant onboarded after this sprint (§2), named for tenants onboarded before it (§ Change Log migration note). |

## 7. Offline behaviour

`GET /settings` is read-cached, same as every other read endpoint — the mobile client caches this
aggressively since it's read on nearly every screen (settings.md's own framing). `PATCH /settings`
is **not offline-queued** — settings.md's own already-documented exception, restated in §2. This
sprint's implementation makes that concrete by simply never adding a `settings.update` operation
type to `sync/push`'s union — there is no queuing path to disable, because none exists.

## 8. Realtime behaviour

None specified for V1 — matching Roles & Permissions' own precedent (no live push when a role
changes mid-session). A device that already cached `GET /settings` keeps using the stale value
until its next fetch; since `PATCH /settings` requires connectivity in the first place (§2), the
window of staleness on other devices is bounded by ordinary cache-refresh behaviour, not an offline
queue draining unpredictably.

## 9. UI specification

None this sprint — `PATCH /settings` is a back-office, Owner-only action with no mobile screen yet
(a `/settings` route per a future [route-map.md](../../09-navigation/route-map.md) addition is not
built). No existing screen changes behaviour this sprint either: nothing yet reads
`tax_mode`/`pricing_mode`/discount thresholds, since Discount/Tax (M2 items 3/4) haven't been built.

## 10. Test plan

- Unit tests (`settings/service.test.ts`): `getSettings` returns the full shape for
  Manager/Owner and omits both threshold fields for Cashier; `updateSettings` rejects a stale
  `base_updated_at` with `SETTINGS_CONFLICT`; rejects a nonzero `tax_rate_basis_points` combined
  with a resulting non-`'standard'` `tax_mode` with `TAX_RATE_REQUIRES_STANDARD_MODE` (covering
  both "this request sets tax_mode away from standard while keeping a nonzero rate" and "this
  request sets a nonzero rate while the existing row's tax_mode is already non-standard"); rejects
  `printer_config`/`receipt_template_config` in the body with `VALIDATION_FAILED`; a partial update
  changes only the submitted fields, leaving the rest untouched.
- **Live verification, real database, throwaway tenant (deleted after):**
  1. Onboarding a fresh tenant → exactly one `shop_settings` row exists, matching §2's defaults
     exactly (`tax_mode: 'unregistered'`, `tax_rate_basis_points: 0`, `pricing_mode: 'inclusive'`,
     `rounding_rule: 'round_half_up'`, `currency_code: 'INR'`, thresholds `50000`/`100000`).
  2. `GET /settings` as the Owner → full shape, including both threshold fields.
  3. `GET /settings` as a Cashier-role user (seeded directly, same technique Sprint 23 used after
     hitting Supabase's invite rate limit) → threshold fields absent from the response entirely.
  4. `PATCH /settings` as the Cashier → `403 PERMISSION_DENIED`.
  5. `PATCH /settings` as the Owner, `{ tax_mode: "standard", tax_rate_basis_points: 500 }` (5%),
     correct `base_updated_at` → `200`, `GET /settings` reflects both new values.
  6. `PATCH /settings` again with the **same, now-stale** `base_updated_at` from step 5's request →
     `409 SETTINGS_CONFLICT`.
  7. `PATCH /settings` with `{ tax_mode: "unregistered" }` only (rate left at the now-nonzero 500)
     → `422 TAX_RATE_REQUIRES_STANDARD_MODE`.
  8. `PATCH /settings` with `{ printer_config: {} }` → `422 VALIDATION_FAILED`.
  9. Cross-tenant RLS: tenant B's session reads zero of tenant A's `shop_settings` row via `GET
     /settings` (in practice, resolves to *tenant B's own* row instead, per the tenant-scoped
     query — never an error, never a cross-tenant leak).

  **26/26 checks passed.** Two real bugs found running this verification, both fixed before merge:
  (a) onboarding's response crashed with a genuine `500` — `NextResponse.json` cannot serialize the
  new row's two `BIGINT` columns; fixed by keeping `identity/service.ts#onboard`'s response shape
  exactly as it already was (`tenant`/`store`/`user`/`ownerRole`), not by adding `BigInt` formatting
  for a field the documented onboarding contract never returned in the first place. (b) The
  throwaway script applying `012_rls_shop_settings.sql` split the file naively on `;` and filtered
  out any chunk starting with `--`, which silently dropped the leading `ALTER TABLE ... ENABLE ROW
  LEVEL SECURITY` statement along with the file's comment header — the policy was created but never
  enforced. Found by checking `pg_class.relrowsecurity` directly rather than trusting the script's
  own success output; fixed by executing that statement directly and re-verifying `true`.

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [DR-008](../../03-functional-requirements/business-rules.md) (tax formula's `tax_rate` source) | §1, §3 | Met for V1's single flat rate; per-product/per-HSN rate is a named, deferred gap |
| [DR-009](../../03-functional-requirements/business-rules.md) (composition/unregistered → no tax breakup) | §2, §5, §6 | Met — `tax_rate_basis_points` cannot be nonzero outside `'standard'` |
| [DR-012](../../03-functional-requirements/business-rules.md) (discount auto-approval threshold, config half) | §2, §3 | Met — the threshold now exists and is readable/writable; the *enforcement* half is M2 item 3 (Discount), not this sprint |
| [DR-021](../../03-functional-requirements/business-rules.md) (Owner-only settings configuration) | §4, §6 | Met |
| [permission-matrix.md — Settings](../../05-personas/permission-matrix.md#settings) | §4 | Met for tax/rate/rounding/currency/thresholds; printer pairing and receipt-template configuration remain unbuilt (§1) |
| [conflict-resolution.md §4](../../13-offline-sync/conflict-resolution.md#4-the-one-deliberate-exception--shop_settings-does-not-field-merge) (whole-row reject, no field merge) | §2, §6, §10 | Met |
| [seed-data.md](../../07-database/seed-data.md) (safest-universal-default framing) | §2 | Met for `tax_mode`; business-type-based per-vertical seeding remains a named, deferred gap |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | First version — written to drive Sprint 25's implementation of Settings (backlog.md M2 item 1): `shop_settings` table, a default row written at onboarding, `GET`/`PATCH /settings` with role-shaped reads and whole-row optimistic concurrency. Two real gaps found and closed in the same pass: no `shop_settings` row was ever created anywhere in code (dependency-graph.md's "sensible defaults" assumption didn't hold), and neither `shop_settings` nor `products` ever named where DR-008's tax rate actually comes from (resolved as a dated correction to schema-server.md/money-and-tax.md — a single shop-wide flat rate, not a per-product table). |
| 0.1.1 | 2026-08-14 | §10 corrected after implementation and live verification (26/26): two real bugs found and fixed — onboarding's response crashed serializing the new row's `BIGINT` columns (fixed by keeping the onboarding response shape unchanged, not adding formatting for a field it never returned), and the RLS-enable statement was silently dropped by the verification script's own naive comment-splitting logic (found by checking `pg_class.relrowsecurity` directly, not by trusting the script's own output). |
