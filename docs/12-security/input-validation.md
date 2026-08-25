# Input Validation

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.2.0
> **Last updated:** 2026-08-26
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
performs the same validation locally — **correction (Sprint 75): not via generated Dart types**, as
originally written here. [shared-contracts.md](../08-folder-structure/shared-contracts.md)'s own
OpenAPI-codegen mechanism was designed but never implemented (see that document's own §0); mobile
validation is hand-written Dart, kept consistent with the server's Zod rules by this project's own
established cross-referencing discipline rather than shared codegen. The practical guarantee this
paragraph cares about — a Cashier sees a validation problem immediately, offline, rather than
discovering it only at sync time — still holds; only the mechanism achieving it was misdescribed.
The server-side check is authoritative and never skipped on the assumption the client already
validated, per this phase's fail-closed rule — this part was never in question.

## 2. Reject, never silently coerce

Malformed input (a negative quantity, a discount exceeding 100%, a phone number in the wrong shape)
is **rejected with `VALIDATION_FAILED`**, never silently clamped, truncated, or coerced into a
"reasonable" value. Silent coercion is a correctness hazard specifically in a financial application
— a discount silently clamped from 150% to 100% could mask a genuine data-entry or client bug that
the Cashier needed to see and correct, not have quietly absorbed.

## 3. SQL injection is a structural non-issue, not a discipline one

Every database query goes through Prisma ([backend-structure.md](../08-folder-structure/backend-structure.md)'s
repository layer), which parameterises queries by construction — there is no code path that builds
a SQL string by concatenating user input, confirmed by grep: zero uses of `$queryRawUnsafe` or
equivalent anywhere in `apps/web/src`. **Correction (Sprint 75):** no lint rule actually enforces
this — checked directly against `apps/web/eslint.config.mjs`, no such rule exists, the same "never
actually built" status `layering-rules.md`'s own Dart import-boundary rule and `ci-workflows.md`'s
own `import-boundaries` CI job already admit for themselves. The guarantee holds today because
nobody has written the pattern, not because tooling would catch it if someone did — a discipline
dependency this section originally claimed didn't exist.

## 4. What the shared OpenAPI schema was supposed to buy — corrected, Sprint 75

This section originally described [openapi.yaml](../11-api/openapi.yaml) as the single source both
the Zod schemas (server) and generated Dart types (client) are kept consistent with, per
[shared-contracts.md](../08-folder-structure/shared-contracts.md)'s "generated, not committed"
decision — a real design, never built (see that document's own §0). `openapi.yaml` itself has been
stale since Sprint 01 and does not describe the real API. In practice, a validation rule (e.g.
`quantity` must be a positive decimal string) is authored independently in each language's own
hand-written code, not once in a shared spec — the risk this section originally named (client and
server validation logic silently drifting apart) is real and structurally unmitigated today, not
closed the way this section previously claimed. Named honestly here rather than left implying a
protection that doesn't exist.

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
| 0.2.0 | 2026-08-26 | Sprint 75: corrected §1 and §4, which both described the OpenAPI-generated-Dart-types mechanism as real and operative — it was designed (`shared-contracts.md`) but never built, found and named there in the same pass. §4's specific claim (validation rules authored once, drift structurally prevented) is now known to be false in practice — the risk it described as closed is real and open, named honestly rather than left implying a protection that doesn't exist. Also corrected §3: no CI lint rule actually bans raw SQL (`$queryRawUnsafe`), confirmed against `eslint.config.mjs` directly — the guarantee holds today only because nobody has written the pattern, the same "designed, never built" status this project's own Dart import-boundary lint rule and `import-boundaries` CI job already admit for themselves. |
