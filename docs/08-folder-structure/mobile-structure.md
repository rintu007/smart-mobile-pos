# Mobile Structure (Flutter)

> **Status:** 🔵 In review
> **Phase:** 08 — Folder Structure
> **Version:** 0.1.1
> **Last updated:** 2026-08-26
> **Owner:** Principal Flutter Engineer
> **Approved by:** _pending_

Feature-first, per this phase's founding rule. Eleven feature folders group the seventeen V1 modules
by user-facing cohesion, not 1:1 with the [module registry](../modules/README.md) — that registry
tracks business/delivery status; this document organises code. The two are different, valid axes
over the same seventeen modules, and there is no requirement they match folder-for-folder.

(The registry counts Categories, Units, and Products as three separate specification rows — since
each gets its own `modules/<name>/` folder — where [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)'s
strategic "16-module V1 boundary" groups them into one "Products, Categories, Units" row for
business-scoping purposes. Both figures are correct for their own axis; this document's "eleven
feature folders" claim is checked against the registry's 17 operational rows specifically, since
that's the axis a folder actually maps to.)

---

## 1. Top-level `lib/` structure

```
apps/mobile/lib/
├── main.dart
├── app/                      # App shell — composition root, not a feature
│   ├── router.dart           # Go Router — merges every feature's routes
│   ├── theme.dart
│   └── providers.dart        # Riverpod root providers (DI wiring)
├── core/                     # Cross-cutting primitives — see §3
│   ├── database/             # Drift setup, schema, migrations (schema-local.md)
│   ├── network/              # Dio client, interceptors, hand-written API contract types (not
│   │                         #   generated — shared-contracts.md's own §0 corrects this, Sprint 75)
│   ├── sync/                 # Offline sync engine — cross-cutting, not a feature (Phase 13)
│   ├── money/                # Money value type (ADR-0006) and its arithmetic
│   ├── auth/                 # Session/token primitives shared by every feature's data layer
│   └── errors/                # Error taxonomy types, shared across features
└── features/
    ├── onboarding/
    ├── authentication/
    ├── catalogue/            # Categories + Units + Products — managed together (schema-server.md Context 2)
    ├── inventory/
    ├── customers/
    ├── pos/
    ├── sales_history/        # Viewing past sales/invoices — distinct screens from the till itself
    ├── cash_drawer/          # Trading Day open/close/reconcile
    ├── returns/
    ├── reports/
    └── settings/             # Includes user/role management and audit-log viewing
```

## 2. Per-feature anatomy — identical in every feature folder

```
features/<feature_name>/
├── domain/
│   ├── entities/              # Plain Dart classes/Freezed models — no Flutter, no Dio, no Drift
│   ├── repositories/          # Abstract interfaces only (e.g. ProductRepository)
│   └── use_cases/             # Business operations composing one or more repositories
├── data/
│   ├── repositories/          # Concrete implementations of the domain interfaces
│   ├── data_sources/          # Local (Drift) and remote (Dio/API) data sources
│   └── models/                # DTOs / Drift row mappers — converts wire/row shape to domain entities
└── presentation/
    ├── screens/
    ├── widgets/                # Widgets used only within this feature
    └── providers/              # Riverpod providers/notifiers wiring domain use cases to UI state
```

A feature that's simpler than this (e.g. `cash_drawer`, with little domain logic beyond what's
already in `core/money`) still uses the same three folders — consistency of location matters more
than saving a folder for a small feature, per this phase's exit criterion that placement is never a
judgment call.

## 3. What belongs in `core/`, and what doesn't

`core/` holds primitives **every feature needs and none of them owns** — a database connection, an
HTTP client, the Money type, the error taxonomy, session/auth primitives. It is not a place to put
something merely because it's shared by two features; if only `pos` and `returns` need something,
it likely belongs in one of them with the other importing it explicitly (see
[layering-rules.md](layering-rules.md) on why *that* specific case is still usually wrong, and what
to do instead). `core/` is deliberately small and named-by-purpose (`core/money`, not `core/utils`)
— per this phase's rule against dumping grounds.

## 4. Composition root — the one place new features are "registered"

`app/router.dart` and `app/providers.dart` are the **only** files touched when a new feature is
added — each feature exports its own `routes` list and its own top-level Riverpod providers; the
app shell imports and merges them. This is a deliberate, narrow exception to "adding a module
requires no change to any existing file": the exit criterion's intent is that **features never
touch each other's files**, not that a composition root cannot exist at all — a system with truly
zero central registration point would need auto-discovery code generation that is not justified at
V1's scale. Stated explicitly here so it isn't mistaken for a violation later.

## 5. Module-to-feature-folder mapping

| V1 module (registry) | Feature folder |
| --- | --- |
| Authentication | `authentication` |
| Company & Store Setup | `onboarding` (initial setup) + `settings` (ongoing configuration) |
| Roles & Permissions | `settings` (management UI) + `core/auth` (enforcement primitives used everywhere) |
| Audit Log | `settings` (viewer screen) |
| Categories, Units, Products | `catalogue` |
| Inventory — Stock Ledger | `inventory` |
| Customers (basic) | `customers` |
| POS | `pos` |
| Sales & Invoices | `sales_history` (POS itself lives in `pos`; this is for viewing/reprinting past sales) |
| Receipt & Printing | `pos` (printing is triggered from the sale-completion flow) + `core` (the printer driver abstraction, since [R-05](../01-vision/risks-constraints-assumptions.md) wants it usable from settings' test-print too) |
| Returns & Refund | `returns` |
| Cash Drawer / Day Close | `cash_drawer` |
| Reports | `reports` |
| Settings | `settings` |
| Offline Sync Engine | `core/sync` — cross-cutting, not a feature a user navigates to, per [04-srs/srs.md §2.2](../04-srs/srs.md) |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial feature-first structure: 11 feature folders, per-feature 3-layer anatomy, module mapping. |
| 0.1.1 | 2026-08-26 | Sprint 75: corrected `core/network/`'s folder-tree comment, which said API contract types come "from packages/contracts" — that generation mechanism was designed but never built (`shared-contracts.md §0`); the real folder holds hand-written types, confirmed by direct inspection (`api_client.dart`, `device_registration_api.dart`, no generated subdirectory). |
