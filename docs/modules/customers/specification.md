# Module Specification — Customers (basic)

> **Status:** 🟢 Approved
> **Module:** Customers (basic)
> **Slice:** V1, minimal — `customers` table, `sales.customer_id`, `POST`/`GET`/`PATCH`/`DELETE
> /customers`, `GET /customers/{id}/purchase-history` (Sprint 31); `customer.create` sync-push,
> `POST /sales` accepting `customer_id`, and the mobile UI (Sprint 32); the conflict-resolution
> field-merge policy live end to end — `customer.update` sync-push, `PATCH /customers/{id}` upgraded
> to the same merge-aware logic, `customer_field_conflicts`, `GET /customers/conflicts`,
> `POST /customers/conflicts/{id}/resolve`, and the mobile edit/conflict-resolution screens
> (Sprint 35, backlog.md M3 item 5 — **M3's last item**).
> **Version:** 0.5.0
> **Last updated:** 2026-08-19
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 31](../../17-sprints/sprint-31.md); extended (§1a and throughout) to drive
[Sprint 32](../../17-sprints/sprint-32.md) and, again (§1c), [Sprint 35](../../17-sprints/sprint-35.md)
— specification before code, per [docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

[backlog.md M3 item 1](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point):
the server half of Customers — the smallest module in this API, deliberately
([customers.md](../../11-api/endpoints/customers.md)'s own framing: name, phone, purchase lookup,
not a full CRM). This is the first M3 item; M2's own closure ([Sprint 30](../../17-sprints/sprint-30.md))
left M3 fully decomposed but unstarted.

**Everything this spec needs was already fully fixed in Phases 03/07/11** —
[customers.md](../../11-api/endpoints/customers.md), the `customers` table in
[schema-server.md Context 4](../../07-database/schema-server.md), and FR-050/051/052 all predate
this sprint unchanged. No design gap was found writing this spec, the same "not every sprint needs
one" honesty [sprint-29.md](../../17-sprints/sprint-29.md) already modelled for Split Payment — worth
stating plainly rather than manufacturing a gap-hunt where none exists.

**One real decision made now, at planning time, not previously written down anywhere:** `sales`
already has a `customer_id` column documented in schema-server.md's Context 5 (`sales`) — this sprint
adds it as **nullable**, matching every other post-M0 `sales` column addition's own precedent
(`trading_day_id`, `canonical_invoice_number`), since a customer is optional on a sale
(FR-050/customers.md never require one) and there is no existing data to backfill regardless. `POST
/sales` itself is **not** extended to accept `customer_id` in this sprint — that belongs to
[backlog.md M3 item 2](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point)
(the mobile checkout-flow wiring that actually produces a customer selection to send), the same
"column exists and is populated by every code path that can populate it, but nothing populates it
yet" shape [trading-day/specification.md §1](../trading-day/specification.md#1-purpose-and-business-context)
already established for `trading_day_id`. Building the column with no caller is still correct
groundwork, not speculative — item 2 depends on it existing.

**Scope explicitly not in Sprint 31, named rather than silently dropped:** mobile UI (item 2);
`customer.create`/`customer.update` sync-push operation types and offline queuing (items 2 and 5);
the conflict-resolution field-merge policy itself (item 5) — Sprint 31's `PATCH /customers/{id}` is
a plain last-write-wins online update, no base-`updated_at` comparison, since no concurrent-offline-
edit caller exists yet to make a merge policy meaningful. Building it now would be exactly the kind
of speculative abstraction this project's own practice avoids — see
[backlog.md §4](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point)'s
own reasoning for why item 5 is scoped separately.

## 1a. Sprint 32 — Customers (mobile), M3 item 2

[Sprint 31](../../17-sprints/sprint-31.md) built and named exactly what item 2 needs: the
`customer_id` column with no caller, and no `customer.create` sync-push type. This sprint closes
both, plus the mobile UI itself.

**`customer.create` reuses the `product.create` shape exactly, not a new pattern.** Mobile's
`DriftCustomerRepository.createCustomer` writes the local `customers` row and enqueues a
`customer.create` `outbound_queue` entry in the same transaction — identical to
`DriftProductRepository.createProduct`'s own established shape (Sprint 07), not Categories/Units'
online-only-direct-call shape, since `customers.md` documents `POST /customers` as genuinely
offline-queued, unlike `POST /categories`/`POST /units`. `sync/service.ts` gains `customer.create`
in its `TYPE_ORDER` and dispatch, calling `customersService.createCustomer` unchanged — sync-api.md
§1's "push does not define a second, parallel request schema" rule, held exactly as every prior
operation type has held it.

**`POST /sales` gains an optional `customer_id`, validated server-side against the caller's own
tenant if supplied** — the same tenant-scoped existence check `products/service.ts` already
established for `category_id`/`unit_id`: an invalid/foreign-tenant value is rejected with the
already-generic `NOT_FOUND`, matching that exact precedent rather than inventing a new
per-field error code for what is already a well-established shape.

**Reads stay direct-fetch-and-cache, not a new sync-pull cursor.** FR-052's "matched against the
locally cached customer list" needs a local cache warm enough to search offline, but building a
full bidirectional `GET /sync/pull?entity_type=customers` cursor mechanism for a single new read
path is real, undiscussed scope disproportionate to what this item needs. Mirrors Categories/Units'
own `refreshFromServer()` shape instead (Sprint 20): a direct `GET /customers` call populates/
refreshes the local cache, `listAll()`/`searchByPhone()` then query that cache offline. Purchase
history (`GET /customers/{id}/purchase-history`) is fetched live, on demand, with no local cache at
all — the same shape `sales-history`'s own detail screen already established for read-through data
that doesn't need offline availability for a feature (FR-051's own offline classification) whose
primary use is "look this customer up while online, at the till."

**Capture is a bottom sheet over the till screen, not a route push — FR-050's own wording, taken
literally.** "captured inline during checkout without leaving the sale screen" is a real UI
constraint, not just a data-shape one: the till screen gains a Customer chip (next to Hold, in the
same row) opening a modal `CustomerPickerSheet` — phone-as-you-type search against the local cache,
tap a match to attach it to the active cart, or (no match) an inline two-field form that creates
and attaches in the same action. `/customers` and `/customers/:id` remain full routes for the
separate browse/purchase-history use case (reached via a new `pos_customers_button` app-bar icon,
the same entry-point shape Hold/Resume's own `pos_held_carts_button` established in Sprint 30) —
two distinct entry points for two distinct jobs, not one screen serving both awkwardly.

**The active cart's attached customer survives hold/resume**, the same durability guarantee
[FR-026](../../03-functional-requirements/functional-requirements.md) already requires for line
items (Sprint 30) — `CartState` gains `customerId`/`customerName`/`customerPhone`, persisted on the
local `sales` draft row alongside the cart's other fields, restored on resume.

## 1c. Sprint 35 — Conflict-resolution field-merge, M3 item 5 (M3's last item)

[backlog.md M3 item 5](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point):
the sync engine's first `.update` operation type of any kind, and
[milestones.md — M3](../../16-milestones/milestones.md)'s own hard exit criterion: *"a field-edit
conflict on a customer record (two devices, same field, different values) surfaces in the exact
business-language form specified in
[conflict-resolution.md](../../13-offline-sync/conflict-resolution.md), not a placeholder."*
`customers.md`'s own Sprint 31 implementation note already named this as `PATCH /customers/{id}`'s
own forward-declared future requirement ("the conflict-resolution field-merge policy `PATCH` needs
to actually honour concurrent offline edits — is item 5's scope"), so **`PATCH` itself is upgraded
in this sprint**, not superseded by a separate `customer.update`-only mechanism — both the direct
endpoint and the sync-push operation type call the identical, newly-merge-aware
`updateCustomer` service function, holding sync-api.md §1's "push calls the exact same service
method as the direct endpoint" rule intact rather than treating this as an exception to it.

**The field-level 3-way merge this needs cannot be computed from `base_updated_at` alone — a real
design gap found while writing this spec, before code.** conflict-resolution.md §3 describes the
policy as "the server compares the fields touched by each edit," but the server has no field-level
edit history for `customers` (no audit-log entries are written on `PATCH` today, and building one
purely to reconstruct historical field values would be new, disproportionate scope for a two-field
table). Resolved instead with a per-field 3-way comparison requiring no server-side history at all:
the client already knows, from its own last pull, the value each field it's about to change *had*
at that time — its own **base value** — so `PATCH`'s request body is extended to carry it alongside
the new value for every field position (both `name` and `phone`, always both, not only the changed
one — see §5 for why). For each field:

- `current == base` (nobody else touched this field since this device last knew it) → apply the new
  value outright, whether or not the field actually changed.
- `current != base` and `current == new value` (someone else already set it to exactly what this
  edit also wants) → no-op, not a conflict — the desired end state already holds.
- `current != base` and `current != new value` (someone else changed it to something else, and this
  edit disagrees) → **the genuine field-edit conflict** conflict-resolution.md §3 describes. That
  field is **not** applied — it stays at its current (already-committed) value — and a
  `customer_field_conflicts` row is written recording both candidates, awaiting a Manager/Owner's
  decision. Every other field in the same request that isn't in conflict still applies normally, in
  the same call.

This is a genuine per-field 3-way merge (base/current/new) computed entirely from data the request
itself carries — no new server-side history mechanism, no speculative generalisation to
`categories`/`units`/`products` (none of which has a mobile edit screen either, the same scoping
reason [backlog.md §4](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point)
already gave for keeping this item `customers`-only). `base_updated_at` itself is carried in the
request (matching conflict-resolution.md §3's own vocabulary) but is not separately branched on in
the implementation — it is mathematically subsumed by the per-field comparison above (when it
matches the row's actual `updated_at`, every field's `base` trivially equals `current` too, so the
general algorithm already produces the identical "apply everything" result the whole-row fast path
would) — kept for request-shape fidelity to the already-approved cross-cutting document, not as a
second, materially different code path.

**A second real gap found while writing this spec: the worked example attributes each candidate
value to a named person ("Priya set it to..."), which needs to know who actually set the currently-
applied value — information no existing column captures** (`customers` only has `created_by`, never
an editor). Resolved with one new column, `customers.updated_by` (nullable — null for a customer
never edited since creation, in which case its creator is attributed instead), set on every
successful field application. `customer_field_conflicts` stores `current_set_by`/`attempted_set_by`
(both `users.id`) alongside each candidate value; `GET /customers/conflicts` resolves both to
`display_name` in its response so the mobile prompt can render the worked example's exact wording
without a second round-trip.

**Where an unresolved conflict is stored and resolved — new, minimal scope, not
`sync_rejections`.** `sync_rejections` (named-but-deferred in Sprint 33, M3 item 3) is a different
concept entirely — a post-hoc *permission* re-validation failure — and remains out of scope here.
A field-edit conflict is a *data* disagreement, not a rejected operation, and needs its own small
table: **`customer_field_conflicts`** (new, tenant-scoped) — `id`, `tenant_id`, `customer_id`,
`field` (`'name'` | `'phone'`), `current_value`, `attempted_value`, `created_at`, and
`resolved_at`/`resolved_value`/`resolved_by` (all nullable until decided). Two new endpoints,
Manager/Owner only (matching `DELETE /customers/{id}`'s own role gate, and
[sync-ui.md §2](../../13-offline-sync/sync-ui.md#2-what-tapping-the-indicator-does)'s framing of
conflicts as something needing "the Owner/Manager's attention"): `GET /customers/conflicts` (list
unresolved) and `POST /customers/conflicts/{id}/resolve` (`{ resolved_value }`, which must equal
either `current_value` or `attempted_value` — the worked example's own "a single tap to pick one,"
not open-ended free text, which would be new, undiscussed scope). Resolving simply writes the chosen
value to the customer row (bumping `updated_at` normally) and marks the conflict row resolved. This
review flow is **online-only** — a Manager/Owner reviewing conflicts that may have originated on a
different device already needs connectivity to see them, the same reasoning
[settings.md](../../11-api/endpoints/settings.md)'s own online-only stance already established for
a comparably rare, low-frequency administrative action.

**A deliberate, dated contract change to `PATCH /customers/{id}`, not a silent break.** Sprint 31's
original request shape (`{ name?, phone? }`, true partial-update semantics) is replaced with the
merge-aware shape (§5) — a real, documented break from the original contract, judged safe because no
mobile caller of `PATCH` has ever existed (Sprint 32 built browse/purchase-history screens only, no
edit screen) — the same "no real caller yet, so the timing is free" reasoning
[customers/specification.md §1](#1-purpose-and-business-context)'s own `sales.customer_id` addition
already used.

**Mobile**: the local `Customers` table gains no new columns (`updatedAt` already exists, per §3's
own note that it was added ahead of need specifically for this item). A new `CustomerEditScreen`
(`/customers/:id/edit`) is the sprint's first mobile customer-edit UI at all — writes locally
(optimistic, using the pre-edit local row as `base_name`/`base_phone`) and enqueues `customer.update`
atomically, the same `DriftCustomerRepository.createCustomer`-established shape. A new
`ConflictsScreen` (`/customers/conflicts`, Manager/Owner — shown to every role per the same
no-client-side-role-awareness stance [returns/specification.md §1b](../returns/specification.md#1b-sprint-34--returns--refund-mobile-m3-item-4)
already established, the server's own `403` surfaced honestly rather than gated) renders the
worked example's exact prompt: *"[Name]'s [field] was changed by two people at the same time. \[value
A\]. \[value B\]. Which is correct?"* — two tappable choices, never a raw form. A badge on the same
Till-screen icon family (`pos_customer_conflicts_button`) mirrors the returns-approvals badge shape
Sprint 34 already established, reusing the identical swallowed-403-means-no-badge mechanism for a
Cashier.

## 1d. Sprint 46 — Customer erasure (found unbuilt during Sprint 43's OWASP checklist review)

[privacy.md §4](../../12-security/privacy.md#4-deletion--reconciling-erasure-rights-with-ledger-immutability)
fully designed the anonymise-not-delete resolution for a customer erasure request since Phase 12 —
Sprint 43's OWASP-checklist-against-real-code review (backlog.md M4 item 8) found it had never
actually been implemented, alongside the equally-unimplemented on-device encryption and mobile
secure-storage gaps that document's finding M6 named. This item closes that specific gap.

`POST /customers/{id}/erase`, **Owner only** — one level stricter than `DELETE`'s Manager+Owner
gate, since this is a real data-governance/legal-compliance action a shop's Owner should decide, not
an ordinary back-office judgment call like deactivation. No request body: the target id travels via
the URL, and there is nothing else to supply — an erasure request either anonymises the row or is an
idempotent replay of one already done, no partial form exists.

Server: `name`/`phone` overwritten with `null`, a new `erased_at` timestamp column set, and
`deactivated_at` set too if it wasn't already (§2's own new bullet explains why). The response shape
for every customer object (not only this endpoint's own) gains `deactivated_at`/`erased_at` — a
related, previously-unexposed gap found in the same pass: this API had never surfaced deactivation
status at all, despite `DELETE /customers/{id}` setting it since Sprint 31.

**Mobile UI is explicitly out of scope this sprint** — no screen exists anywhere in this product for
an Owner to *initiate* an erasure request; the realistic V1 flow is a customer's request reaching the
Owner outside the app entirely (a phone call, a message) and the Owner acting on it via a future
admin surface. Building that surface is real, separate, undiscussed scope — this item closes the
*server-side capability* privacy.md §4 already designed, not a new UI feature.

## 2. Business rules

- **A customer record needs at least one of `name`/`phone`** — `CUSTOMER_IDENTIFIER_REQUIRED`
  otherwise, so a record is never created with no way to ever look it up again
  ([customers.md](../../11-api/endpoints/customers.md)).
- **`phone` is unique per tenant among active (non-deactivated) customers** —
  `(tenant_id, phone) WHERE deactivated_at IS NULL`, per schema-server.md. `PATCH` can collide with
  this same constraint (moving a customer's phone onto one already assigned elsewhere), not only
  `POST`.
- **Soft delete only.** `DELETE /customers/{id}` sets `deactivated_at`, never removes the row —
  `sales.customer_id` is `ON DELETE SET NULL`-safe regardless, but the historical sale record must
  never be blocked or altered by a later customer-record change
  ([customers.md](../../11-api/endpoints/customers.md), BR-030's immutability principle extended to
  the referencing side).
- **Deactivating an already-deactivated customer is an idempotent no-op** — returns the existing
  deactivated state unchanged, the same idempotent-state-transition stance
  [roles/service.ts's `deactivateUser`](../../../apps/web/src/modules/roles/service.ts) already
  established for the structurally identical `users.deactivated_at` case.
- **`GET /customers` excludes deactivated customers by default** (an inactive customer shouldn't
  resurface in checkout search or return-lookup) — no query parameter to include them this sprint;
  named as a small, deliberate simplification, not a documented requirement either way.
- **Purchase history only ever lists `sales` with `status = 'completed'`** — a draft/held sale is
  never attributable to a customer's history, matching FR-051's "prior *completed* sales" wording
  exactly.
- **Field-edit conflicts (Sprint 35, §1c)** — a `PATCH`/`customer.update` field whose current server
  value differs from both the request's own base value *and* its new value is not applied; it is
  recorded in `customer_field_conflicts` for Manager/Owner resolution instead. `assertHasIdentifier`
  is checked against the *resulting* merged state (fields that did apply plus fields left at their
  current, un-conflicted value) — the same "checked against the merged result, not either value in
  isolation" stance already established for ordinary `PATCH`.
- **Resolving a conflict accepts only one of the two recorded candidate values** — no free-text
  override, matching the worked example's own "a single tap to pick one."
- **Erasure anonymises, never deletes (Sprint 46, §1d).** `POST /customers/{id}/erase` overwrites
  `name`/`phone` with `null` and sets `erased_at`; the row's own `id` survives so historical
  `sales.customer_id` FKs stay valid, per [privacy.md §4](../../12-security/privacy.md#4-deletion--reconciling-erasure-rights-with-ledger-immutability).
  Deliberately bypasses `assertHasIdentifier` (§2's own "at least one of name/phone" rule) — an
  erased customer legitimately has neither, the one documented exception to that rule. Also sets
  `deactivated_at` if not already set (an erased customer has no identifying data left for any real
  workflow to search, add to a sale, or show in the picker by). Idempotent, same shape as
  deactivation.

## 3. Database tables and relationships

New table: `customers`, matching schema-server.md's documented shape exactly: `id`, `tenant_id`,
`name` (nullable), `phone` (nullable), `deactivated_at` (nullable), plus the standard
`created_at`/`updated_at`/`created_by`. `updated_at` is included even though schema-server.md's own
column list doesn't name it explicitly — every other Client-editable, PATCH-capable Tier 1 table
(`shop_settings`) already carries one, and [backlog.md M3 item 5](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point)'s
conflict-resolution merge policy needs it to exist as a real column later — adding it now avoids a
second migration purely to bolt it on. `erased_at` (nullable, Sprint 46, §1d) added later — the
explicit state marker §2's own erasure bullet explains.

Index: `(tenant_id, phone) WHERE deactivated_at IS NULL` (unique) — the return-by-phone lookup
(FR-062) and inline checkout search (FR-052), and the actual mechanism behind §2's uniqueness rule.

`sales` gains `customer_id` — nullable `UUID REFERENCES customers(id) ON DELETE SET NULL`, matching
schema-server.md's own documented `ON DELETE SET NULL` exactly (the one FK in this sprint that
*isn't* `RESTRICT`, since a sale must survive its customer's later removal, per §1/§2).

RLS: tenant-scoped, same template as every other table
([supabase/sql/014_rls_customers.sql](../../../supabase/sql/014_rls_customers.sql)).

`customers` gains `updated_by` (nullable `UUID REFERENCES users(id) ON DELETE SET NULL`, Sprint 35,
§1c) — the actor of the most recent successful field application, for conflict attribution.

**`customer_field_conflicts` (new, Sprint 35, §1c)** — `id` (server-generated), `tenant_id`,
`customer_id` (`REFERENCES customers(id) ON DELETE CASCADE` — a conflict has no meaning once its own
customer is gone), `field` (`TEXT`, `'name' | 'phone'`), `current_value`/`attempted_value`
(`TEXT`, nullable, mirroring the customer fields' own nullability), `current_set_by`/
`attempted_set_by` (`UUID REFERENCES users(id)`, both `NOT NULL` — the worked example's own
attribution requirement), `created_at`, `resolved_at`/`resolved_value`/`resolved_by` (all nullable
until decided). Index: `(tenant_id, resolved_at) WHERE resolved_at IS NULL` — the unresolved-
conflicts queue. RLS: tenant-scoped, standard template.

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/customers` | **Built this sprint.** Cashier, Manager, Owner. `id` (client-generated UUIDv4, creation-style idempotency — matches `products`/`categories`'s own upsert-on-id pattern), `name`/`phone` (at least one required). |
| `GET /api/v1/customers` | **Built this sprint.** Any authenticated role. Filter: `phone` (exact match). Cursor-paginated on `(updated_at, id)`, matching `products`'s own convention. Excludes deactivated customers (§2). |
| `PATCH /api/v1/customers/{id}` | **Upgraded Sprint 35 (§1c) — breaking contract change, no prior mobile caller existed.** Cashier, Manager, Owner. Merge-aware: `base_updated_at`, `base_name`, `base_phone`, `name`, `phone` (all required — §5). Per-field 3-way merge against the concurrently-current row; a genuine same-field conflict is not applied, recorded in `customer_field_conflicts` instead, response still `200` (the fields that weren't in conflict still applied). |
| `DELETE /api/v1/customers/{id}` | **Built this sprint.** Manager, Owner only. Soft delete (§2), idempotent. |
| `POST /api/v1/customers/{id}/erase` | **Built Sprint 46 (§1d).** Owner only. Anonymises `name`/`phone` to `null` (row/id survive), sets `erased_at` and `deactivated_at` (if unset). Idempotent. |
| `GET /api/v1/customers/{id}/purchase-history` | **Built this sprint.** Any authenticated role. Cursor-paginated `sales` for this customer, `status = 'completed'` only (§2), ordered `(completed_at, id)` desc. |
| `POST /api/v1/sales` | **Extended Sprint 32.** `customer_id` accepted as an optional field, per §1a. When supplied, must resolve to a real `customers` row under the caller's tenant (`NOT_FOUND` otherwise) — deactivated customers are still valid targets (§2's soft-delete stance: a deactivated customer can still complete a sale in progress, only future *lookup* excludes them). |
| `POST /api/v1/sync/push` (`customer.create`) | **Built Sprint 32** — §1a. Dispatches to the same `customersService.createCustomer` `POST /customers` already calls, per sync-api.md §1. |
| `POST /api/v1/sync/push` (`customer.update`) | **Built Sprint 35 (§1c) — the sync engine's first `.update` operation type of any kind.** Same payload shape as the upgraded `PATCH` body (with `id` added, since a push operation has no URL — the same structural difference `return.approve`/`return.reject`'s own sync payloads already established, [returns/specification.md §5](../returns/specification.md#5-validation-rules-client-and-server)). Dispatches to the same, now-merge-aware `customersService.updateCustomer`. |
| `GET /api/v1/customers/conflicts` | **Built Sprint 35 (§1c).** Manager, Owner only. Unresolved `customer_field_conflicts`, most-recent-first. |
| `POST /api/v1/customers/conflicts/{id}/resolve` | **Built Sprint 35 (§1c).** Manager, Owner only. `{ resolved_value }`, must equal `current_value` or `attempted_value`. Writes the chosen value to the customer row and marks the conflict resolved. Online-only (§1c). |

Route files: `customers/route.ts` (POST, GET — a static top-level file, no dynamic sibling risk),
`customers/[id]/route.ts` (PATCH, DELETE), `customers/[id]/purchase-history/route.ts`,
`customers/[id]/erase/route.ts` (POST, §1d), `customers/conflicts/route.ts` (GET),
`customers/conflicts/[id]/resolve/route.ts` (POST) — the `conflicts/` pair are static siblings of
`customers/[id]/route.ts`, not nested under it, applying Sprint 23/24's own static-vs-dynamic routing
lesson proactively from the start (the same lesson `POST /users/invite` learned the hard way — a
literal `conflicts` segment must never fall through to `[id]`'s own dynamic match); `erase/` *is*
nested under `[id]/`, the same unambiguous shape `returns/[id]/approve/route.ts` already uses (a
static child of a dynamic segment carries no collision risk, unlike two static top-level siblings
of a dynamic one).

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `id` (create) | UUID v4 — Zod `.uuid()`. |
| `name` | `.string().trim().min(1).max(200).optional()`. |
| `phone` | `.string().trim().min(1).max(20).optional()`. At least one of `name`/`phone` enforced via `.refine()`, not per-field — `CUSTOMER_IDENTIFIER_REQUIRED` on violation. |
| `phone` (query filter) | `.string().trim().min(1).max(20).optional()`. |
| PATCH body (Sprint 35, §1c) | `base_updated_at` (`.string().datetime()`), `base_name`/`base_phone`/`name`/`phone` (all `.string().trim().min(1).max(...).nullable()`, all **required** — not the original partial-update shape). All four are required, not just the changed field(s), because the merge logic needs each field's base value to detect overlap regardless of which field(s) this particular edit actually intends to change (§1c) — a client always knows its own currently-cached `name`/`phone` before editing, so this is never a real burden on the caller. |
| `customer.update` sync payload | Same four fields as `PATCH`'s body, plus `id` (the target customer, no URL to carry it in a push batch). |
| `resolved_value` (conflict resolution) | `.string().nullable()` — must equal the conflict's own `current_value` or `attempted_value` (checked in the service layer, not by Zod, since Zod can't see the row being resolved). |

**A real bug found live (Sprint 31's own verification script), not by inspection:** the "at least
one of name/phone" rule was first written as a Zod `.refine()` on `createCustomerRequestSchema`,
following [pos/schema.ts](../../../apps/web/src/modules/pos/schema.ts)'s own precedent for the
mutually-exclusive discount fields. Live-testing surfaced the difference that precedent didn't
share: a `.refine()` failure is indistinguishable from any other shape violation at the Route
Handler's `safeParse` boundary, so the endpoint always returned the generic `VALIDATION_FAILED` —
never the specific `CUSTOMER_IDENTIFIER_REQUIRED` [customers.md](../../11-api/endpoints/customers.md)
names for exactly this condition. Discount's own `.refine()` has no named code to preserve, so the
precedent held there; this rule does, so it doesn't transfer. Fixed by removing the `.refine()`
entirely and relying solely on `service.ts`'s `assertHasIdentifier()`, matching this codebase's own
"business rules live in the service layer, not the Route Handler" convention
([backend-structure.md §2](../../08-folder-structure/backend-structure.md)) for any rule that needs
a specific, documented error code.

## 6. Error handling and user-facing messages

| Code | HTTP | Cause |
| --- | --- | --- |
| `CUSTOMER_IDENTIFIER_REQUIRED` | 422 | Already reserved (error-catalogue.md). Both `name` and `phone` omitted on create, or a PATCH would leave both null. |
| `PHONE_ALREADY_ASSIGNED` | 409 | Already reserved. The `(tenant_id, phone) WHERE deactivated_at IS NULL` unique index's `P2002`, translated — on create or on a PATCH that moves `phone` onto an already-assigned value. |
| `NOT_FOUND` | 404 | `PATCH`/`DELETE`/purchase-history target an `id` that doesn't exist under the caller's tenant; `resolve` targets a nonexistent or already-resolved conflict `id`. |
| `PERMISSION_DENIED` | 403 | `DELETE`/`GET /customers/conflicts`/`resolve` called by a Cashier. |
| `VALIDATION_FAILED` | 422 | Any Zod failure. |
| `CONFLICT_RESOLUTION_VALUE_INVALID` | 422 | *New, Sprint 35.* `resolved_value` matches neither the conflict's `current_value` nor `attempted_value`. |

## 7. Offline behaviour

**`POST /customers` is genuinely offline-capable (Sprint 32)**, per §1a: local write +
`outbound_queue` enqueue, atomic in one Drift transaction, drained by the existing sync trigger
(Sprint 14) with no changes needed there. **`customer.update` is built this sprint (Sprint 35, §1c)**
— the same local-write-plus-enqueue shape, atomic, genuinely offline-capable: an edit made offline
queues normally and is merge-resolved once it syncs, whenever that is, exactly the scenario the
worked example's two devices exercise. `GET /customers`/`GET /customers/{id}/purchase-history` are
not sync-pulled (§1a's direct-fetch-and-cache decision) — the local `customers` cache is refreshed
via a direct online call, offline search works against whatever was last fetched, the same staleness
shape Categories/Units already established. `GET /customers/conflicts`/`resolve` are online-only
(§1c) — no local conflict cache, no offline queuing for resolution itself.

## 8. Realtime behaviour

None specified for V1 — no requirement found for a live push when a customer record changes on
another device. Matches every other module's own precedent (Roles & Permissions, Settings, Trading
Day): the next request re-resolves state fresh, no cross-session push.

## 9. UI specification

**Built Sprint 32**, per §1a:

- **`CustomerPickerSheet`** — a modal bottom sheet launched from a new `pos_customer_chip` on the
  till screen (next to `pos_hold_button`), showing "Add customer" when the cart has none attached,
  or the attached customer's name/phone when it does. Phone-as-you-type search (`pos_customer_search`
  field) against the local cache; tapping a result attaches it (`pos_customer_result_<id>`); an
  inline two-field form (`pos_customer_new_name`/`pos_customer_new_phone`, a
  `pos_customer_create_button`) creates-and-attaches when no result matches. Closing the sheet
  without a selection leaves the cart's existing attachment (or lack of one) unchanged.
- **`CustomersScreen`** (`/customers`) — reached via a new `pos_customers_button` app-bar icon on
  the till screen, the same entry-point shape `pos_held_carts_button` established. Search field,
  scrollable result list (`customers_list`, rows keyed `customers_row_<id>`), empty state
  (`customers_empty`). Not a select flow — tapping a row navigates to detail.
- **`CustomerDetailScreen`** (`/customers/:id`) — name/phone header, purchase history list
  (`customer_history_list`, fetched live per §1a, empty state `customer_history_empty`).

Tablet/phone: single-column list + sheet, no distinct tablet layout needed — matches every other
V1 screen's own precedent (no module has needed one yet).

**FR-050's "without leaving the sale screen," checked against
[tap-count-audit.md](../../09-navigation/tap-count-audit.md)'s standard, not previously verified
numerically:** attaching an *existing* customer from the sheet is tap chip → tap search result (2
taps), the same order of magnitude as WF-003's own audited discount flow (5 steps including a typed
amount, per that row's own count). Creating a *new* customer inline (tap chip → type phone → tap
create) is comparable in shape — a typed field plus a confirming tap, not a new tap-count category
this document's existing rows don't already cover.

**Built Sprint 35**, per §1c:

- **`CustomerEditScreen`** (`/customers/:id/edit`) — reached from `CustomerDetailScreen`'s new
  `customer_edit_button`. Two fields (`customer_edit_name_field`/`customer_edit_phone_field`,
  pre-filled from the local cache), a `customer_edit_save_button`. Saving writes locally (using the
  screen's own pre-edit values as `base_name`/`base_phone`) and enqueues `customer.update` — no
  blocking network call, the save always succeeds locally regardless of connectivity, per §1c/§7.
- **`ConflictsScreen`** (`/customers/conflicts`) — a plain list (`customer_conflicts_list`, rows
  keyed `customer_conflict_row_<id>`, empty state `customer_conflicts_empty`); tapping a row expands
  the worked example's exact prompt in place, attribution included: *"\[Customer name\]'s \[field\]
  was changed by two people at the same time. \[current_set_by.display_name\] set it to
  \[current_value\]. \[attempted_set_by.display_name\] set it to \[attempted_value\]. Which is
  correct?"* with two tappable choice buttons
  (`customer_conflict_choice_current_<id>`/`customer_conflict_choice_attempted_<id>`) — never row
  IDs, timestamps, or "conflict"/"version"/"base" vocabulary anywhere in the rendered text,
  per [sync-ui.md §4](../../13-offline-sync/sync-ui.md#4-what-is-deliberately-never-shown). A
  Cashier who reaches this screen (nothing prevents navigation, per the no-role-awareness stance)
  sees the server's own `403` as the same plain error state every other list screen already uses.
- **Till screen** gains `pos_customer_conflicts_button` (→ `/customers/conflicts`, with a live
  unresolved-count `Badge`, the identical swallowed-403-means-no-badge mechanism
  [returns/specification.md §1b](../returns/specification.md#1b-sprint-34--returns--refund-mobile-m3-item-4)
  already established for the returns-approvals badge).

## 10. Test plan

- Unit tests (`customers/service.test.ts`): `createCustomer` — creates with only `name`, only
  `phone`, or both; rejects both-omitted with `CUSTOMER_IDENTIFIER_REQUIRED`; translates the phone
  unique-constraint violation to `PHONE_ALREADY_ASSIGNED`; a replayed `id` is an idempotent no-op
  (same shape `createProduct`'s own upsert-on-id test already covers). `updateCustomer` — **superseded
  by Sprint 35's merge-aware rewrite, below** (originally: partial update of `name` only, `phone`
  only, or both; a PATCH that would leave both fields null is rejected the same way creation is;
  translates a phone collision the same way creation does; a PATCH on a nonexistent `id` is
  `NOT_FOUND` — all of which still hold under the new shape, just expressed via `base_name`/
  `base_phone` equal to the unchanged field's own current value rather than an omitted key).
  `deactivateCustomer` — sets `deactivated_at`; idempotent replay on
  an already-deactivated customer; `NOT_FOUND` on a nonexistent `id`. `listCustomers` — filters by
  exact `phone`; excludes deactivated customers; cursor pagination round-trips correctly (peek-and-
  trim, same pattern as `listProducts`). `getPurchaseHistory` — only `status = 'completed'` sales
  returned, ordered `(completed_at, id)` desc; `NOT_FOUND` on a nonexistent customer `id`.
- **Live verification, real database, throwaway tenant (deleted after):**
  1. `POST /customers` with only `phone` → `201`.
  2. `POST /customers` with neither `name` nor `phone` → `422 CUSTOMER_IDENTIFIER_REQUIRED`.
  3. A second `POST /customers` with the same `phone` (different `id`) → `409 PHONE_ALREADY_ASSIGNED`.
  4. `GET /customers?phone=<the number>` → the created customer, exact match.
  5. `PATCH /customers/{id}` with a new `name` → `200`, `phone` unchanged.
  6. `PATCH /customers/{id}` moving `phone` onto a second, already-assigned customer's phone → `409
     PHONE_ALREADY_ASSIGNED`.
  7. A completed sale created with this customer's `id` directly against the database (no `POST
     /sales` change this sprint — §1), then `GET /customers/{id}/purchase-history` → the sale
     appears; a draft/held sale for the same customer does not.
  8. `DELETE /customers/{id}` as a Cashier → `403 PERMISSION_DENIED`; as the Owner → `200`,
     `deactivated_at` set; a second `DELETE` → identical response, idempotent.
  9. `GET /customers` after step 8 → the deactivated customer is excluded.
  10. Cross-tenant RLS: tenant B's `GET /customers` never resolves to tenant A's customer.

**Sprint 32 additions:**

- Unit tests: `pos/service.test.ts` — `createSale` accepts a valid `customer_id` and links it;
  rejects one that doesn't exist under the caller's tenant with `NOT_FOUND`; a sale with no
  `customer_id` is unchanged from before. `sync/service.test.ts` — `customer.create` dispatches to
  `customersService.createCustomer`; a validation failure is rejected the same way `product.create`'s
  own bad-payload case already is.
  `drift_customer_repository_test.dart` (real in-memory Drift DB): `createCustomer` writes the
  local row and an `outbound_queue` entry atomically (the same multi-row atomicity proof
  `drift_product_repository_test.dart` already established); `searchByPhone` matches a partial
  prefix; `refreshFromServer` upserts without duplicating.
- **Live verification, real database:** `POST /sales` with a valid `customer_id` links it, visible
  in the customer's own `purchase-history`; an invalid `customer_id` → `404 NOT_FOUND`; a sync-push
  batch containing a `customer.create` operation creates the row exactly as the direct endpoint
  would, confirmed via a follow-up `GET /customers?phone=`.
- **Mobile:** `flutter analyze`/`flutter test` — `CustomerPickerSheet` attaches an existing customer
  to the active cart, or creates-and-attaches a new one; `CustomersScreen` search filters the local
  list; `CustomerDetailScreen` renders purchase history; hold-then-resume preserves the attached
  customer.

**Sprint 35 additions (M3 item 5, the field-merge policy):**

- Unit tests (`customers/service.test.ts`, rewritten `updateCustomer` group): no concurrent edit
  (`base_updated_at` matches) applies both fields outright; a non-overlapping field pair (Device A's
  base/current/new for `name`, Device B's for `phone`) both apply in independent calls with no
  conflict; the exact worked example — two devices' conflicting `phone` values — the *first* call
  applies cleanly, the *second* call's `phone` is **not** applied (row's `phone` stays at the first
  call's value), a `customer_field_conflicts` row is written with both candidate values, and the
  *other* field in the second call (if unrelated and non-conflicting) still applies; a request whose
  new value happens to already equal the current (already-changed-by-someone-else) value is a
  silent no-op, no conflict row written; `assertHasIdentifier` checked against the final merged
  state. `listConflicts`/`resolveConflict` — lists only unresolved rows; resolving with a value
  matching neither candidate is rejected (`CONFLICT_RESOLUTION_VALUE_INVALID`); resolving writes the
  chosen value to the customer row and marks the conflict resolved; a second resolve attempt on an
  already-resolved conflict is an idempotent no-op (returns the already-resolved state, the same
  `approveReturn`/`deactivateCustomer` shape), not an error.
- Unit tests (`sync/service.test.ts`): `customer.update` dispatches to the same, now-merge-aware
  `customersService.updateCustomer`; a bad payload is rejected the same way every other operation
  type's own bad-payload case already is.
- **Live verification, real database, throwaway tenant (deleted after) — the exit criterion itself,
  provoked for real:**
  1. Create a customer with `name`/`phone` both set.
  2. "Device A" (`PATCH`) changes `phone` to a new value, `base_name`/`base_phone` matching the
     customer's actual current values → `200`, applied.
  3. "Device B" (`PATCH`, using the *original* `base_updated_at`/`base_phone` from before step 2)
     changes `phone` to a *different* new value → `200`, but `GET /customers/{id}` afterward shows
     Device A's value, not Device B's.
  4. `GET /customers/conflicts` (Manager) → one unresolved row, `field: "phone"`, both candidate
     values present, exactly the worked example's own shape.
  5. `POST /customers/conflicts/{id}/resolve` with Device B's value → `200`; `GET /customers/{id}`
     now shows Device B's value; `GET /customers/conflicts` → empty.
  6. `POST /customers/conflicts/{id}/resolve` again (same value) → `200`, idempotent no-op — the
     same already-decided-state-transition shape `approveReturn`/`deactivateCustomer` already
     established, not an error.
  7. `POST /sync/push` with a `customer.update` operation → `accepted`, applied identically to the
     direct endpoint.
  8. Cross-tenant RLS: tenant B's `GET /customers/conflicts` never resolves tenant A's conflict.
- **Mobile:** `flutter analyze`/`flutter test` — `CustomerEditScreen` saves locally and enqueues
  `customer.update` with the pre-edit values as `base_name`/`base_phone`; `ConflictsScreen` renders
  the empty state, a populated list, and the exact two-choice prompt; tapping a choice resolves it;
  the Till badge reflects a fake conflicts-list length and shows nothing when the fake throws (the
  Cashier case, mirroring Sprint 34's own returns-approvals badge test).

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| FR-050 (inline capture during checkout) | §4 (`POST /customers`), §1a/§9 (mobile picker sheet) | Met (Sprint 32) |
| FR-051 (purchase history on profile) | §2, §4, §9, §10 | Met |
| FR-052 (phone-match-as-you-type search) | §4 (`GET /customers?phone=`), §1a/§9 (mobile local-cache search) | Met (Sprint 32) |
| FR-062 (return lookup by customer phone) | §3 (phone index), §4 | Server half met; consumed by [backlog.md M3 item 3/4](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point) (Returns) |
| FR-026 (durability guarantee, extended to the attached customer) | §1a | Met (Sprint 32) — survives hold/resume |
| [permission-matrix.md — Customers](../../05-personas/permission-matrix.md#customers) | §4 | View/add/purchase-history met; edit/deactivate rows were missing from that matrix entirely — added Sprint 31 as a dated correction |
| `customers.md`'s offline-queued write endpoints | §7 | `POST /customers` met (Sprint 32, `customer.create`); `PATCH`/`customer.update` met (Sprint 35) |
| Conflict-resolution field-merge (conflict-resolution.md) | §1c, §2–§7, §9, §10 | **Met (Sprint 35)** — the field-level 3-way merge, the worked example's own prompt rendered verbatim, `shop_settings`' own separate whole-row-reject stance (§4 of that document) unaffected |
| [milestones.md — M3 exit criterion](../../16-milestones/milestones.md) (field-edit conflict surfaces in business language) | §1c, §9, §10 | **Met (Sprint 35)** — live-verified end to end, the exact two-device scenario provoked for real |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-16 | First version — written to drive Sprint 31's implementation of Customers (backlog.md M3 item 1): `customers` table, `sales.customer_id` (nullable), `POST`/`GET`/`PATCH`/`DELETE /customers`, `GET /customers/{id}/purchase-history`. No design gap found — customers.md/schema-server.md/FR-050-052 were already fully fixed. Mobile UI, offline queuing, and the conflict-resolution merge policy are explicitly out of scope, named for M3 items 2 and 5. |
| 0.2.0 | 2026-08-16 | Built and live-verified (12/12). Found and fixed a real bug live: a Zod `.refine()` for "at least one of name/phone" always returned the generic `VALIDATION_FAILED` instead of the documented `CUSTOMER_IDENTIFIER_REQUIRED` — removed in favour of the service-layer check that already existed, §5. Permission matrix's missing edit/deactivate rows corrected in the same PR (§11). |
| 0.3.0 | 2026-08-16 | §1a added — written to drive Sprint 32 (M3 item 2, Customers mobile): `customer.create` sync-push (reusing `product.create`'s exact shape), `POST /sales` accepting an optional `customer_id`, and the mobile UI itself — `CustomerPickerSheet` (a bottom sheet, per FR-050's own "without leaving the sale screen" wording taken literally) plus full `/customers`/`/customers/:id` routes for browsing. Reads stay direct-fetch-and-cache (Categories/Units' own shape), not a new sync-pull cursor — named as a deliberate, disciplined scope boundary. |
| 0.4.0 | 2026-08-16 | §1c added — written to drive Sprint 35 (M3 item 5, **M3's last item**): the conflict-resolution field-merge policy live end to end. Found a real design gap while writing this spec: `base_updated_at` alone can't support the field-level 3-way merge conflict-resolution.md §3 describes, since the server has no field-level edit history — resolved by having the client send each field's own base value alongside its new value, a genuine, dated contract change to `PATCH /customers/{id}` (no prior mobile caller existed to break). New `customer_field_conflicts` table, `GET /customers/conflicts`/`POST /customers/conflicts/{id}/resolve` (Manager/Owner, online-only), `customer.update` as the sync engine's first `.update` operation type of any kind. Mobile gains its first customer-edit screen and a conflict-resolution screen, both reusing the badge/no-role-awareness patterns Sprint 34 already established for Returns. |
| 0.5.0 | 2026-08-19 | §1d added — written to drive Sprint 46: customer erasure, found unimplemented during Sprint 43's OWASP checklist review (M6) despite `privacy.md §4` fully designing it since Phase 12. `POST /customers/{id}/erase` (Owner only), `erased_at` column, `deactivated_at`/`erased_at` now exposed on every customer response (a related, previously-unexposed gap found in the same pass). Mobile UI explicitly out of scope — no admin surface exists yet for an Owner to initiate a request. |
