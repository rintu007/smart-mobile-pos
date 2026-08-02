# Sprint 07

> **Dates:** 2026-08-02 – 2026-08-02 (single-day, same pattern as Sprints 02–06)
> **Milestone:** M0 — Walking Skeleton
> **Status:** Closed

## Goal

Build the mobile local write path for products (backlog item 5's remaining, mobile-only half) —
an "Add product" screen that writes to the local Drift `products` table and enqueues a
`product.create` operation to `outbound_queue`, per
[sync-architecture.md §1–§2](../13-offline-sync/sync-architecture.md)'s "the local write path is
the one and only way any entity is created or changed on-device" principle.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| 5 (mobile half only — server half shipped Sprint 04) | Products (mobile) | ~1.0 of the item's 1.5 total | 2, 4 — both done |

`POST /api/v1/products`'s server endpoint already exists (Sprint 04); this sprint does not touch
`apps/web`. `products/specification.md §4` already named this exact scope as "deferred past
Sprint 04," so no new module specification is needed — only reaching what §4/§7 already describe.
Found one real gap while planning: [route-map.md](../09-navigation/route-map.md) had a route for
viewing/editing an existing product (`/catalogue/:id`) but none for creating a new one — added
`/catalogue/add` as a dated correction before writing the screen that needed it.

## Capacity check

~1.0 person-day against [sprint-cadence.md](sprint-cadence.md)'s ~3.75 person-day budget — well
inside budget. Deliberately narrow: this sprint does **not** build the product list screen
(`/catalogue`) beyond what's needed to reach the add screen, and does not touch the till screen
(item 6) — both left for a later sprint so this one stays a single, completable slice.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: this sprint's own doc updates (route-map.md correction,
      this file, products/specification.md, module registry, implementation-log, README bumps) are
      inside the estimate above.

## Risks

- **`outbound_queue` has never been read by anything real yet** — Sprint 03 proved it round-trips
  in isolation (`database_test.dart`), but this sprint is the first time a real feature writes to
  it as a side effect of a user action. If the local write and the enqueue aren't atomic (one
  succeeds, the other silently doesn't), a product could exist locally without ever syncing, or a
  queue entry could reference a product that was never actually created — both wrapped in a single
  Drift transaction to rule this out, verified in the demo script below.
- **Same device-target gap as Sprint 06** (retrospective-log.md) — `flutter doctor` still shows no
  usable device beyond Chrome/widget tests; the live-verification approach below follows the same
  pattern established last sprint rather than rediscovering the gap.
- **Money entry without `core/money`** — `mobile-structure.md` plans a `core/money` value type, not
  yet built. This sprint does a plain decimal-string-to-minor-units conversion inline rather than
  building that type now, since nothing yet needs more than one conversion — named explicitly so
  it isn't mistaken for an oversight when a later sprint needs real Money arithmetic.

## Definition of Done

Mobile-only slice — the [Definition of Done](../00-governance/definition-of-done.md) boxes this
sprint's scope can actually satisfy:

- [x] Matches `products/specification.md §4/§7`'s already-approved description of the deferred
      mobile write path — no new specification needed.
- [x] `/catalogue/add` route matches route-map.md's guard (`Manager+` — not enforced yet, no
      permission check exists in M0, same named boundary `products/specification.md §2` already
      states for the server endpoint).
- [x] Local write (`products` table) and the `outbound_queue` enqueue happen in a single Drift
      transaction — verified by a repository test that forces the enqueue to fail and asserts the
      product row does not exist either.
- [x] `outbound_queue` payload matches `sync-api.md §1`'s contract exactly: `entity_type:
      "product.create"`, `payload` identical to `POST /api/v1/products`'s own request shape
      (`{ id, name, price_minor_units }`) — so the sync engine (item 9, not yet built) can call the
      same service logic without a second parallel schema.
- [x] Widget tests for the add-product screen's validation/loading/success states.
- [x] `flutter analyze` clean, `flutter test` green.
- [x] Live verification: a real write through the full stack (screen → controller → repository →
      Drift), confirmed by querying the actual database file afterward, not just a fake in a test.
- [x] Module registry and products/specification.md updated.

**Explicitly not in this sprint's DoD subset:** the product list screen (`/catalogue`) beyond a
minimal entry point, the till screen (item 6), anything sync-engine-related (item 9 — the queue
entry is written but nothing drains it yet, same "queued, not yet pushed" state Sprint 03's local
schema already anticipated).

## Demo script

No local device can run the actual rendered UI (`flutter doctor` — Windows desktop missing its C++
workload, no Android SDK; same gap Sprint 06 found and logged). Same two-part substitute:

**Part A — widget-level UI proof** (`flutter test`, fakes): validation (empty name, negative/
non-numeric price), the loading state during an in-flight write, and a thrown failure rendering as
inline error text.

**Part B — real local-database proof** (a temporary `flutter test` script using a real file-backed
`NativeDatabase`, not `.memory()`, deleted after): create the real `AppDatabase`, call the actual
`DriftProductRepository.createProduct(...)`, close the connection, reopen a **fresh** connection to
the same file (a stronger proof than reading back from the same open connection), then:
1. Query `products` directly — assert exactly one row with the expected `name`/`priceMinorUnits`. ✅
2. Query `outbound_queue` directly — assert exactly one row, `entityType = 'product.create'`,
   `status = 'queued'`, and `payload` parses to `{ id, name, price_minor_units }` matching the
   product row exactly. ✅
3. Force the same write again with the same client-generated `id` (simulating a retry) — assert no
   second `products` or `outbound_queue` row is created (idempotent, matching the server's own
   `POST /api/v1/products` behaviour). ✅

## Environment findings

- **System memory hit 0.7 GB free mid-sprint**, crashing `flutter analyze` ("Could not reserve
  virtual memory"). Traced to 33 leftover Chrome processes (~3.2 GB) that outlived Sprint 06's
  `flutter run -d chrome` demo, despite the wrapper task having been stopped. Resolved by the
  founder closing Chrome directly — not guessed at, since a process list alone can't reliably
  distinguish "leftover demo instance" from "the founder's actual open tabs." Logged as a
  retrospective entry below since it's a concrete process change.
- A real name collision (Drift's generated `Product` row class vs. this feature's own domain
  `Product` entity) was caught immediately by `flutter analyze` and fixed with a scoped
  `hide Product` import — not an environment issue, but worth noting as a pattern: any future
  feature naming an entity after its own table should expect this collision and hide it proactively
  rather than wait for the analyzer to catch it.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md): after any `flutter run -d <device>` demo,
explicitly verify the launched browser/process actually terminated — stopping the wrapper task is
not the same guarantee, and this sprint's memory exhaustion traces directly to that gap.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-02 | Sprint 07 planned: closes backlog item 5's remaining mobile-only scope (local product write path), the second concrete action against the mobile-UI-deferral risk. Found and fixed a real route-map.md gap (no route existed for creating a new product). |
| 0.2.0 | 2026-08-02 | Sprint 07 closed: `/catalogue/add` built, tested (8 new tests: 3 repository + 5 widget), and verified against a real on-disk SQLite file across a fresh connection. A real memory-exhaustion environment issue (leftover Chrome processes) diagnosed and resolved with the founder's help, not guessed at. PR pending. |
