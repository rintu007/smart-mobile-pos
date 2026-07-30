# Assumptions & Dependencies

> **Status:** 🔵 In review
> **Phase:** 04 — Software Requirement Specification
> **Version:** 0.1.1
> **Last updated:** 2026-07-31
> **Owner:** CTO
> **Approved by:** _pending_

This is the **engineering-dependency** view: for each external system or hardware element the
running product touches, what happens if it is unavailable, and whether the architecture already
degrades gracefully or that's still an open question. Distinct from
[risks-constraints-assumptions.md](../01-vision/risks-constraints-assumptions.md), which is the
Phase 01 business-level risk register — this document is narrower and operational.

---

## External service dependencies

| Dependency | What breaks if unavailable | Degradation behaviour |
| --- | --- | --- |
| Supabase Postgres (via API) | No sync; no server-side visibility for the owner remotely | **Graceful.** Local POS continues fully per [BR-003](../02-business-requirements/business-requirements.md); operations queue and drain once restored ([FR-079](../03-functional-requirements/functional-requirements.md)). |
| Supabase Auth | New logins and new device registrations fail | **Graceful for existing sessions.** Already-authenticated devices continue offline per [FR-013](../03-functional-requirements/functional-requirements.md); only genuinely new logins are blocked. |
| Supabase Realtime | Live cross-device updates (e.g. another till's stock change) stop pushing | **Graceful — resolved.** The background-timer sync trigger ([sync-architecture.md §4](../13-offline-sync/sync-architecture.md#4-what-opportunistic-not-scheduled-means-concretely)) is the periodic-pull fallback; see [failure-scenarios.md §4](../13-offline-sync/failure-scenarios.md#4-resolving-the-realtime-outage-fallback). |
| Supabase Storage | Product image and receipt-PDF upload/download fails | **Graceful for the core sale.** Product images already cached locally continue to display; new images queue; receipt printing/sharing (which doesn't depend on Storage) is unaffected. |
| Vercel (API host) | All server-side operations unavailable | **Graceful for POS, not for anything server-dependent.** Local selling is unaffected; sync, remote reporting, and new registrations wait until restored. |
| Google Play Store | New installs/updates blocked | **No mitigation needed.** Pure distribution channel; already-installed instances are unaffected. |
| Firebase Cloud Messaging | Not present in V1 | N/A — this dependency does not exist until notifications ship in V3. |
| Payment gateway | Not present in V1 | N/A — V1 is cash/manual-method only; this dependency arrives with V3. |
| Map tile provider | Not present in V1 | N/A — arrives with V3 delivery tracking. |

## Hardware dependencies

| Dependency | What breaks if unavailable | Degradation behaviour |
| --- | --- | --- |
| Device camera | Barcode scanning unavailable | **Graceful.** Text/SKU search is a required fallback, not optional — [BR-012](../02-business-requirements/business-requirements.md)/[FR-025](../03-functional-requirements/functional-requirements.md). |
| Bluetooth ESC/POS printer | Physical receipt printing fails | **Graceful.** Digital share (image/PDF) is a required fallback; a completed sale never depends on print success — [BR-034](../02-business-requirements/business-requirements.md)/[BR-035](../02-business-requirements/business-requirements.md). |
| Device clock | Could be wrong (timezone change, manual adjustment, dead battery) | **Handled by design, not degraded.** Device clock is used only for user-facing display; **server time is authoritative for all sync ordering** — a wrong device clock cannot corrupt event order. Formal rule to be finalised in [13-offline-sync](../13-offline-sync/README.md). |
| Device storage | Full storage could block local queue writes | **Resolved — tiered response.** Proactive pruning of bounded read caches, `outbound_queue` never pruned, an honest persistent low-storage warning as the last resort — see [failure-scenarios.md §3](../13-offline-sync/failure-scenarios.md#3-resolving-the-storage-full-open-item). |

## Data / correctness assumptions

| Assumption | Risk if wrong | Status |
| --- | --- | --- |
| The launch market is India, and GST rules as researched are accurate | Entire tax/invoice implementation would need rework | **Provisional** — [OD-01](../01-vision/open-decisions.md), unconfirmed. |
| The regulatory research in [regulatory-requirements.md](../02-business-requirements/regulatory-requirements.md) is correct | Non-compliant invoices issued to real customers | **Unverified against primary sources** — qualified GST practitioner review required before any compliance claim, per that document's own open items. |
| Per-tenant infrastructure usage matches the modelled assumptions in [cost-model.md](../02-business-requirements/cost-model.md) (10 MB DB growth/shop/month, etc.) | Pricing margin assumptions could be wrong | **Modelled, not measured** — flagged there for pilot validation ([A-08](../01-vision/risks-constraints-assumptions.md)). |
| Free-to-paid conversion reaches ~15% | Revenue projections in [pricing-strategy.md](../02-business-requirements/pricing-strategy.md) would need revision | **Industry-benchmark placeholder**, not our own data. |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial dependency catalogue. Two open items flagged for Phase 13 (Realtime-outage fallback, storage-full behaviour). |
| 0.1.1 | 2026-07-31 | Both Phase-13-flagged items resolved; cross-referenced to [failure-scenarios.md](../13-offline-sync/failure-scenarios.md). |
