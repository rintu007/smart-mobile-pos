# Guards & Redirects

> **Status:** 🔵 In review
> **Phase:** 09 — Navigation
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** UI-UX Lead / Principal Flutter Engineer
> **Approved by:** _pending_

Four guard types, evaluated in this order on every route access attempt (later guards only run if
earlier ones pass).

---

## 1. Authentication guard

**Check:** does a valid, non-revoked session exist locally?

| Outcome | Behaviour |
| --- | --- |
| Valid cached session, any connectivity state | Access granted — [FR-013](../03-functional-requirements/functional-requirements.md), a session is validated locally once issued |
| No session at all | Redirect to `/auth/login` |
| Session exists but was remotely revoked, and this device has since synced | Redirect to `/auth/login` with a clear message — not a silent stall |
| Session exists, was revoked, but this device **hasn't synced since** | **Access still granted locally** — the device cannot know about a revocation it hasn't heard about yet. This is an accepted, bounded consequence of offline-first design ([R-09](../01-vision/risks-constraints-assumptions.md)), not a bug: the revocation takes effect at the device's next connectivity, per [QA-005](../04-srs/quality-attributes.md). |

## 2. Onboarding-completion guard

**Check:** has this tenant completed [FR-001](../03-functional-requirements/functional-requirements.md)–[FR-005](../03-functional-requirements/functional-requirements.md)?

| Outcome | Behaviour |
| --- | --- |
| Incomplete | Redirect to whichever `/onboarding/*` step was last incomplete — never back to the start, per the ten-minute promise not tolerating repeated work |
| Complete | Access granted to the shell |

## 3. Permission guard

**Check:** does the authenticated user's role (per [permission-matrix.md](../05-personas/permission-matrix.md)) include the requesting route's required permission?

| Outcome | Behaviour |
| --- | --- |
| Permitted | Access granted |
| Denied | **Redirect to `/pos`, not an error screen.** A Cashier attempting `/reports` via a guessed or bookmarked URL is sent home, not shown a broken or confusing "access denied" page — consistent with [project-vision.md §5](../01-vision/project-vision.md)'s zero-technical-knowledge stance; a denial screen a Cashier doesn't understand is a support-ticket generator, a silent redirect to somewhere useful is not. |
| Denied, but the attempted action was queued offline before the permission was revoked | Handled at sync per [DR-018](../03-functional-requirements/business-rules.md) — this guard concerns navigation access, not the separate sync-time re-validation already specified in [tenancy-model.md](../07-database/tenancy-model.md)/[offline-workflows.md](../06-workflows/offline-workflows.md). |

## 4. Subscription-state guard — deliberately does not exist

**There is no guard that blocks navigation to `/pos` (or any sale-completing route) based on
free-tier transaction limits, payment status, or any commercial state.** This is stated as an
explicit non-decision, not an oversight: [project-vision.md §11](../01-vision/project-vision.md)
commits to never charging for offline capability or access to a business's own data, and
[BR-003](../02-business-requirements/business-requirements.md)/[BR-004](../02-business-requirements/business-requirements.md)
make "never stop selling" an architectural absolute. A guard that could block a sale for a
commercial reason — even a soft one like a reached free-tier cap — would violate both, and would be
particularly dangerous applied offline, where the shop has no way to resolve it in the moment.

**What does happen** when a free-tier cap is reached (per [pricing-strategy.md §3](../02-business-requirements/pricing-strategy.md)):
a non-blocking prompt/banner, surfaced the same way sync status is surfaced
([BR-053](../02-business-requirements/business-requirements.md)) — informational, dismissible,
never gating the Till route itself.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial four guards. Subscription guard explicitly ruled out, with the reasoning stated to prevent it being added later without re-litigating why. |
