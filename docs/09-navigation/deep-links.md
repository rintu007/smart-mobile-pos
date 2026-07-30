# Deep Links

> **Status:** 🔵 In review
> **Phase:** 09 — Navigation
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** UI-UX Lead / Principal Flutter Engineer
> **Approved by:** _pending_

**V1 has exactly one deep-link case.** QR customer ordering, order tracking, and push-notification
targets are all V2/V3 concepts ([scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)) —
listed here for traceability, not designed, consistent with how [06-workflows](../06-workflows/README.md)
and [08-folder-structure](../08-folder-structure/README.md) have treated out-of-scope items
throughout this documentation set.

---

## 1. V1: account verification link

The one real deep link in V1: the link or code sent during
[FR-001](../03-functional-requirements/functional-requirements.md)'s account-verification step,
returning the user to `/onboarding/business-type` (the step immediately after verification)
authenticated as the new tenant.

**Tenant scoping:** the verification token is single-use, short-lived, and bound to the specific
signup attempt that generated it — it authenticates exactly one tenant's onboarding continuation,
never a general-purpose login link. A guessed or intercepted-after-expiry token fails, per standard
verification-token practice; this is Phase 12's implementation detail, not a new decision here.

## 2. What does not exist in V1, and why

| Deep link type | Status | Reasoning |
| --- | --- | --- |
| QR catalogue / customer ordering | Deferred to V3 | Requires the digital storefront module, which doesn't exist yet ([scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)) |
| Receipt links (web-viewable) | Not a V1 concept at all | V1 receipt sharing is **file-based** (image/PDF via the OS share sheet, per [BR-034](../02-business-requirements/business-requirements.md)/[FR-060](../03-functional-requirements/functional-requirements.md)) — there is no hosted receipt URL to deep-link to. A "view your receipt online" web page is a plausible V3+ feature alongside order tracking, not a V1 gap. |
| Order tracking | Deferred to V3 | Requires Shipping & Delivery |
| Push-notification targets | Deferred to V3+ | V1 has no push notifications at all — Firebase Cloud Messaging isn't integrated until a module that needs it ships ([system-context.md](../04-srs/system-context.md)) |

## 3. The standing rule for when these arrive

Stated now so it's not forgotten later, per this phase's exit criterion: **any future deep link
must be authenticated and tenant-scoped such that a guessed link cannot reveal another shop's
data** — the same [tenancy-model.md](../07-database/tenancy-model.md) enforcement (RLS plus
API-layer checks) applies to a deep-linked route exactly as it does to normal navigation; a deep
link is not a side door around tenant isolation. QR catalogue links in particular will need a
public-but-scoped identifier (a shop-specific token in the URL, not a raw database ID) — a design
question for whichever phase specifies V3's QR Ordering module, not resolved here.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | V1 has one real deep link (account verification); everything else deferred with reasoning, and the tenant-scoping rule stated for future deep links. |
