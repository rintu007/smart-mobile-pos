# Input Validation

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Security Engineer / CTO
> **Approved by:** _pending_

Boundary validation strategy and the shared-schema approach — where every request is validated,
using what, and the policy for malformed input.

---

## 1. Where validation happens

Every Route Handler validates its request body against that module's Zod schema
([backend-structure.md](../08-folder-structure/backend-structure.md)'s `schema.ts`) **before**
calling the service layer — per that document's layering rule, a Route Handler that lets malformed
data reach `service.ts` is a layering violation, not just a validation gap. The mobile client
performs the same validation locally (via the equivalent Dart types generated from
[openapi.yaml](../11-api/openapi.yaml), per [shared-contracts.md](../08-folder-structure/shared-contracts.md))
so a Cashier sees a validation problem immediately, offline, rather than discovering it only at
sync time — but the server-side check is authoritative and never skipped on the assumption the
client already validated, per this phase's fail-closed rule.

## 2. Reject, never silently coerce

Malformed input (a negative quantity, a discount exceeding 100%, a phone number in the wrong shape)
is **rejected with `VALIDATION_FAILED`**, never silently clamped, truncated, or coerced into a
"reasonable" value. Silent coercion is a correctness hazard specifically in a financial application
— a discount silently clamped from 150% to 100% could mask a genuine data-entry or client bug that
the Cashier needed to see and correct, not have quietly absorbed.

## 3. SQL injection is a structural non-issue, not a discipline one

Every database query goes through Prisma ([backend-structure.md](../08-folder-structure/backend-structure.md)'s
repository layer), which parameterises queries by construction — there is no code path that builds
a SQL string by concatenating user input. Raw SQL (`$queryRawUnsafe` or equivalent) is a banned
pattern enforced by a lint rule in CI, the same enforcement style already used for the import-
boundary rules in [layering-rules.md](../08-folder-structure/layering-rules.md) — this is treated as
a structural guarantee the codebase's shape provides, not a review checklist item that depends on
every future contributor remembering it.

## 4. What the shared OpenAPI schema buys specifically

[openapi.yaml](../11-api/openapi.yaml) is the single source both the Zod schemas (server) and the
generated Dart types (client) are ultimately kept consistent with, per
[shared-contracts.md](../08-folder-structure/shared-contracts.md)'s "generated, not committed"
decision. This means a validation rule (e.g. `quantity` must be a positive decimal string) is
authored once, in one place, rather than risking the client and server's validation logic silently
drifting apart — a drift that would otherwise let a request the client considers valid arrive at a
server that disagrees, or vice versa, for no reason traceable to an actual business-rule change.

## 5. File uploads — path traversal is structurally avoided, not filtered

Per [system-context.md](../04-srs/system-context.md)'s TB-2b, file upload/download goes through
short-lived signed URLs issued by the API. The object key a signed URL targets is always server-
generated (a UUID, never a client-supplied filename or path fragment) — there is no code path where
a client-controlled string is used to construct a storage path, which removes path traversal as a
category rather than relying on filtering a client-supplied name for `../` sequences.

## 6. Web admin — XSS (V2+, specified now since the pattern is fixed by the framework choice)

The web admin (Server Actions, per [backend-structure.md §4](../08-folder-structure/backend-structure.md#4-server-actions--where-they-live))
is a React application; React escapes rendered content by default. `dangerouslySetInnerHTML` (or an
equivalent raw-HTML-injection path) is a banned pattern outside of a documented, reviewed exception
— there is no V1/V2 feature identified so far that legitimately needs to render user-supplied HTML,
so no exception exists yet.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Validation boundary and reject-not-coerce policy stated; SQL injection, path traversal, and XSS each closed structurally rather than by review discipline alone. |
