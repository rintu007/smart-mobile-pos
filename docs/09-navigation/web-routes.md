# Web Routes (Next.js)

> **Status:** 🔵 In review
> **Phase:** 09 — Navigation
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** UI-UX Lead / Principal Next.js Engineer
> **Approved by:** _pending_

`apps/web` is, for V1, overwhelmingly the API — [project-vision.md §12](../01-vision/project-vision.md)
and [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md) both state web admin is
optional and every operational workflow lives on mobile. This document is short because V1's actual
web *route* surface is small; it is not a placeholder for lack of effort, it's an accurate
reflection of what [08-folder-structure/backend-structure.md](../08-folder-structure/backend-structure.md)
already scoped.

---

## 1. V1 web routes

| Route | Purpose |
| --- | --- |
| `/api/v1/*` | The mobile API contract — not a user-facing route, covered by [11-api](../11-api/README.md), not this phase |
| `/verify` | **Fallback page** for the account-verification link ([deep-links.md](deep-links.md)) when opened on a device without the app installed — shows a clear "open this on your phone" instruction with the shop's name, rather than a broken or confusing page. This is the one genuinely user-facing V1 web route. |

That is the entire V1 web route surface. No landing page, no marketing site, and no admin dashboard
are in scope for this phase — a static marketing page, if wanted, is a content/hosting decision
outside the application's routing concern entirely.

## 2. Deferred — V2+ web admin

| Route (anticipated) | Deferred to | Reasoning |
| --- | --- | --- |
| `/admin/*` | V2 | Full web admin — [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md) |
| `/admin/reports/export` | V2 | Ties to the Accountant persona's export need ([personas.md](../05-personas/personas.md)) |

## 3. Deferred — V3+ public storefront

| Route (anticipated) | Deferred to | Reasoning |
| --- | --- | --- |
| `/shop/:tenant_slug` | V3 | QR customer ordering / digital catalogue |
| `/shop/:tenant_slug/order/:id` | V3 | Order tracking |

Both require a **public-but-tenant-scoped** identifier in the URL (a slug, not a raw database ID),
per the standing rule already stated in [deep-links.md §3](deep-links.md#3-the-standing-rule-for-when-these-arrive)
— a guessed storefront URL must reveal only what that one shop intends to be public, never another
tenant's data. Designed in full when V3 reaches this phase, not here.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | V1 web surface confirmed minimal (API + one verification fallback page); V2/V3 routes listed for traceability only. |
