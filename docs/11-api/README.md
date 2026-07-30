# Phase 11 — API Design

> **Status:** 🔵 In review — all 8 deliverables drafted
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Principal Next.js Engineer / CTO

## Charter

| | |
| --- | --- |
| **Objective** | Define the complete API contract between the mobile client, the web application and the server — including the synchronisation endpoints, which are unlike ordinary CRUD. |
| **Inputs** | Phases 06, 07 and 08 (all 🔵 In review). [OD-03](../01-vision/open-decisions.md) resolved — Option C (hybrid), [ADR-0001](../adr/ADR-0001-hybrid-api-and-direct-realtime-access.md). |

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`api-principles.md`](api-principles.md) | Versioning, naming, cursor pagination, two idempotency mechanisms, error envelope, server-recomputes rule | 🔵 In review |
| [`authentication.md`](authentication.md) | Token issuance (Supabase Auth + Custom Access Token Hook), refresh/rotation, per-request device revocation | 🔵 In review |
| [`endpoints/`](endpoints/README.md) | 7 module documents — identity, catalogue, inventory, customers, sales, returns, settings | 🔵 In review |
| [`sync-api.md`](sync-api.md) | Batch push reusing per-operation service methods, dependency-ordered groups, per-operation partial-failure results, cursor-based pull | 🔵 In review |
| [`realtime.md`](realtime.md) | 5 subscription types; missed-message behaviour resolved via the pull-sync backstop | 🔵 In review |
| [`error-catalogue.md`](error-catalogue.md) | Full flat code namespace, cross-referenced from every endpoint document | 🔵 In review |
| [`rate-limiting.md`](rate-limiting.md) | Limits by endpoint class; Supavisor transaction-mode pooling design | 🔵 In review |
| [`openapi.yaml`](openapi.yaml) | Machine-readable spec for the core transactional path — validated as syntactically correct YAML | 🔵 In review |

## Exit criteria

- [x] Every mutating endpoint is **idempotent** via a client-supplied key — the two mechanisms in
      [api-principles.md §3](api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation)
      cover every mutation shape in the API; no endpoint is documented as "unsafe to retry."
- [x] Every endpoint declares its required permission — the Permission column in every
      [endpoints/](endpoints/README.md) document.
- [x] Every endpoint declares whether the mobile client may call it while offline (queued) or not —
      the Offline column throughout [endpoints/](endpoints/README.md), including the one deliberate
      exception ([settings.md](endpoints/settings.md)'s `PATCH /settings`) with its rationale stated.
- [x] Errors use one envelope with stable codes; clients never parse error prose —
      [api-principles.md §6](api-principles.md#6-error-envelope) and the full
      [error-catalogue.md](error-catalogue.md).
- [x] Pagination is cursor-based on every list endpoint —
      [api-principles.md §4](api-principles.md#4-pagination--cursor-only); no offset-paginated
      endpoint exists anywhere in this API.
- [x] The sync API handles partial batch failure without losing or duplicating any operation —
      [sync-api.md §3](sync-api.md#3-partial-failure-semantics--every-operation-gets-its-own-verdict)
      (per-operation results) and §5 (idempotent replay makes retried batches safe).
- [~] Connection pooling is configured **and load-tested at 10× expected peak** (risk R-07) — the
      design is fixed in [rate-limiting.md §3](rate-limiting.md#3-connection-pooling--the-r-07-mitigation-load-tested-before-ga)
      (Supavisor, transaction mode, dual pooled/direct Prisma URLs); **the load test itself cannot
      run inside a documentation phase** and is tracked forward as a named Phase 14 test-plan item
      and Phase 16 milestone gate, not silently assumed passed.
- [x] No endpoint returns unbounded results — every list endpoint is cursor-paginated with a capped
      `limit` (max 200, [api-principles.md §4](api-principles.md#4-pagination--cursor-only)); every
      aggregate endpoint (a sale, a return) is bounded by the real-world size of what it embeds, per
      [api-principles.md §2](api-principles.md#2-resource-naming).

Seven of eight criteria are directly and fully met by design. The eighth (the load test) is honestly
carried forward as pending execution, not silently assumed — the same treatment given to
[Phase 10's physical-printer testing](../10-design-system/README.md) and
[Phase 05's persona validation](../05-personas/README.md).

## Rules

- **Route Handlers for the mobile API; Server Actions only for the web application's own forms.**
  Server Actions are a framework-internal transport, not a stable versioned contract for a mobile
  client that may be months out of date on a user's device.
- The API is versioned from day one. Old app versions stay in the field for a long time and cannot
  be forced to update mid-trading-day.
- The server never trusts a client-supplied price, total, tax or stock figure. It recomputes and
  compares; a mismatch is a logged, rejected anomaly.
- Every response is bounded, paginated and tenant-scoped by construction, not by a filter someone
  might forget to add.
