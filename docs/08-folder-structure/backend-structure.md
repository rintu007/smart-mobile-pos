# Backend Structure (Next.js)

> **Status:** 🔵 In review
> **Phase:** 08 — Folder Structure
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Principal Next.js Engineer
> **Approved by:** _pending_

Structured around the same feature/module grouping as [mobile-structure.md](mobile-structure.md),
with a backend-appropriate layering: **Route Handler → Service → Repository → Prisma**, one
direction only. Route Handlers serve the mobile API contract; **Server Actions are used only for
the web app's own forms**, per [11-api's charter rule](../11-api/README.md) that Server Actions are
a framework-internal transport, not a stable versioned contract for a client that may be months
out of date.

---

## 1. Top-level structure

```
apps/web/
├── app/
│   ├── api/
│   │   └── v1/                       # Route Handlers — the mobile API contract, versioned
│   │       ├── auth/
│   │       ├── sales/
│   │       ├── stock-movements/
│   │       ├── returns/
│   │       ├── products/
│   │       ├── ...                   # one folder per resource, mirroring schema-server.md tables
│   │       └── sync/                 # push/pull/cursor endpoints — Phase 13's counterpart
│   ├── (admin)/                      # Web admin UI (V2+) — Server Actions live beside these pages
│   └── layout.tsx
├── src/
│   ├── modules/                      # Business logic — mirrors mobile's feature list conceptually
│   │   ├── sales/
│   │   │   ├── service.ts            # Business rules (DR-001–DR-026 live here, not in route handlers)
│   │   │   ├── repository.ts         # Prisma queries only — no business logic
│   │   │   ├── schema.ts             # Zod validation schemas for this module's inputs
│   │   │   └── types.ts
│   │   ├── inventory/
│   │   ├── returns/
│   │   ├── catalogue/
│   │   ├── customers/
│   │   ├── identity/                 # Auth, roles, devices, audit log
│   │   ├── settings/
│   │   └── sync/                     # Idempotency, sync-rejection handling
│   ├── core/
│   │   ├── auth/                     # Token verification, tenant/store context resolution (TB-1, TB-3)
│   │   ├── db/                       # Prisma client singleton, RLS-aware connection setup
│   │   └── errors/                   # Shared error envelope, error codes
│   └── lib/                          # Thin third-party wrappers only (Supabase admin client, etc.)
├── prisma/
│   └── schema.prisma                 # Generated from / kept in sync with schema-server.md
└── package.json
```

## 2. The layering rule, concretely

```
app/api/v1/<resource>/route.ts   →   src/modules/<module>/service.ts   →   src/modules/<module>/repository.ts   →   Prisma
```

- **Route Handlers are thin.** They parse and validate the request (via the module's Zod
  `schema.ts`), call exactly one service method, and shape the response — they contain no business
  logic themselves. A Route Handler that computes a discount or checks a permission directly,
  instead of delegating to `service.ts`, is a layering violation.
- **Services contain the business rules** — this is where every `DR-NNN` from
  [business-rules.md](../03-functional-requirements/business-rules.md) is actually implemented and
  unit-tested, framework-agnostic (a service function takes plain arguments and returns plain
  values or throws typed errors — it never sees a Next.js `Request`/`Response` object).
- **Repositories contain Prisma queries only** — no business logic, no validation. A repository
  method is a thin, testable wrapper around a query; if a repository method needs an `if` statement
  deciding *what* to do rather than just *how* to fetch it, that logic belongs in the service.

## 3. Module-to-table mapping

| `src/modules/` | Owns tables (from [schema-server.md](../07-database/schema-server.md)) |
| --- | --- |
| `identity` | `tenants`, `stores`, `users`, `user_store_roles`, `devices`, `audit_log` |
| `catalogue` | `categories`, `units`, `products`, `product_variants`, `batches` |
| `inventory` | `stock_movements` |
| `customers` | `customers` |
| `sales` | `trading_days`, `sales`, `sale_line_items`, `sale_payments` |
| `returns` | `returns`, `return_line_items` |
| `settings` | `shop_settings` |
| `sync` | `idempotency_keys`, `sync_rejections` |

A module's `repository.ts` is the **only** code in the backend that queries its owned tables
directly — another module needing that data calls the owning module's service, never its
repository, and never queries its tables via its own repository. This is the backend expression of
the same cross-feature rule in [layering-rules.md](layering-rules.md).

## 4. Server Actions — where they live

Confined entirely to `app/(admin)/` route segments, co-located with the page that uses them (e.g.
`app/(admin)/products/actions.ts`), per standard Next.js convention. A Server Action calls the same
`src/modules/*/service.ts` functions the Route Handlers call — **the business logic is never
duplicated between the two transports**, only the thin adaptation layer differs.

## 5. Why Next.js's file-based routing is a genuine advantage here

Adding a new resource under `app/api/v1/` requires creating one new folder — no central route
registry file exists to edit, unlike the mobile app's `router.dart`
([mobile-structure.md §4](mobile-structure.md#4-composition-root--the-one-place-new-features-are-registered)).
This satisfies this phase's "no change to any existing file" exit criterion **exactly**, not just in
spirit, for the backend specifically.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial backend structure: route-handler/service/repository layering, 8-module mapping to Phase 07's tables. |
