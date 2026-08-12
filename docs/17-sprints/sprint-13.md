# Sprint 13

> **Dates:** 2026-08-13 – 2026-08-13 (single-day, same pattern as Sprints 02–12)
> **Milestone:** M0 — Walking Skeleton (backlog item 9)
> **Status:** Closed

## Goal

Connect the mobile local write path (already proven, Sprints 07/09) to the server endpoints that
accept it (already proven, Sprints 04/05) — [backlog.md item 9](backlog.md#1-m0--walking-skeleton-fully-decomposed),
the minimal `POST /sync/push`/`GET /sync/pull` slice
[sync-api.md](../11-api/sync-api.md) already specifies in full.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Sync engine: `POST /sync/push` for `product.create`/`sale.create`, `GET /sync/pull` for `products` | Offline Sync Engine | 3.0 (full item estimate; this sprint takes the backend-only half) | 5, 6 (done Sprints 04/05) |

Backend-only, same alternating split precedent as products (Sprint 04 backend / Sprint 07 mobile)
and sales (Sprint 05 backend / Sprint 09 mobile). See
[sync-engine/specification.md §1](../modules/sync-engine/specification.md#1-purpose-and-business-context)
for the exact cut: two push operation types, one pull entity type, no mobile trigger.

## Capacity check

Backend half only — well under the item's own 3.0-person-day full estimate, similar in shape to how
Sprint 04's slice of item 5 and Sprint 05's slice of item 6 each took less than their item's total.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day — this is the first batch endpoint and the first
      cursor-paginated endpoint in this codebase, both genuinely new patterns.
- [x] Documentation capacity reserved: `sync-engine/specification.md` (new), backlog.md, module
      registry, implementation-log, README bumps.

## Risks

- **First cursor-paginated endpoint in this codebase** — `GET /stores` (Sprint 08) never needed
  pagination (exactly one store per tenant). Verified live with an actual two-page walk (§ Demo
  script), not just asserted from the encoding logic.
- **Mobile-UI deferral, now a fourth instance of the same pattern** Sprints 04/05/etc. already
  named: the outbound queue still isn't drained after this sprint. Named directly as the concrete
  next sprint's content, not left implicit.
- **Scope temptation**: sync-api.md's full six-group ordering and eight-entity-type pull are both
  real, already-approved designs. Building only the two-type/one-entity minimal slice this sprint
  keeps within the backend-only estimate; named in the spec rather than expanded into.

## Definition of Done

- [x] `sync-engine/specification.md` (new), all 11 sections, 🟢 Approved.
- [x] `POST /api/v1/sync/push` — validates the envelope, dispatches each operation to the exact
      same service function its direct endpoint uses, processes `product.create` before
      `sale.create` regardless of submitted order, returns one result per operation in the
      request's own original order, never fails the whole batch for one operation's rejection.
- [x] `GET /api/v1/sync/pull?entity_type=products` — cursor-paginated on `(updated_at, id)`,
      `next_cursor` null on the final page.
- [x] `DEPENDENCY_NOT_FOUND` returned (not `NOT_FOUND`) for a `sale.create` referencing an
      as-yet-unsynced product.
- [x] Unit tests for the service layer (ordering, partial failure, error remapping, cursor
      encode/decode, malformed-cursor rejection).
- [x] `tsc --noEmit` / `eslint` clean.
- [x] Live verification against the real database, throwaway tenants deleted after.
- [x] No secret, token, or key written to logs or committed to source.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** the mobile sync trigger/outbound-queue drain, every
other push operation type or pull entity type, `sync_rejections`, M0's own remaining items (10–11).

## Demo script

**Run 2026-08-13** against the live database, via real HTTP requests to a local dev server pointed
at production Supabase, throwaway tenants deleted after:

1. Onboard tenant A and tenant B (cross-tenant check). ✅
2. `POST /sync/push` as tenant A with one `sale.create` submitted **before** its own
   `product.create` in the request array — both come back `accepted`, proving the two-group
   reordering actually runs (a raw submitted-order pass would have failed the sale on a missing
   product). ✅
3. `POST /sync/push` with a `sale.create` referencing a product id that doesn't exist —
   `DEPENDENCY_NOT_FOUND`, not `NOT_FOUND`. ✅
4. Replay the identical batch from step 2 — both operations still `accepted`, no duplicate rows
   (idempotency inherited from the direct endpoints, not reimplemented here). ✅
5. `GET /sync/pull?entity_type=products&limit=1`, then again with the returned `next_cursor` — two
   distinct products, one per page; the second page's `next_cursor` is `null`. ✅
6. As tenant B, `GET /sync/pull?entity_type=products` — zero of tenant A's products returned. ✅

**A real bug found on the first live attempt, fixed immediately:** step 5's second page came back
with a non-null `next_cursor` even though it was genuinely the last page — a classic
cursor-pagination off-by-one. `listProductsForSync` fetched exactly `limit` rows, so a page that
happened to land exactly on `limit` was indistinguishable from a page with more data after it.
Fixed by fetching `limit + 1` rows as a peek and trimming the extra one off before returning —
its mere presence (or absence) is what actually answers "is there a next page," not the returned
count alone. Re-ran the demo script clean afterward (14/14).

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. One candidate: this is the first sprint whose live
verification actually caught a real logic bug (the cursor off-by-one) rather than only confirming
already-correct code — the "real HTTP request/live verification required" addendum rule
(Sprint 02/04's own precedent) earned its keep concretely here, not just in principle.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-13 | Sprint 13 planned and built same-day: `sync-engine/specification.md` written first, `POST /sync/push` (two operation types) and `GET /sync/pull` (one entity type) built, live-verified against the real database including a reordering proof, a `DEPENDENCY_NOT_FOUND` proof, and a two-page cursor walk. Found and fixed a real cursor-pagination off-by-one bug on the first live attempt (see Demo script). Mobile trigger/outbound-queue drain explicitly deferred to the next sprint. |
