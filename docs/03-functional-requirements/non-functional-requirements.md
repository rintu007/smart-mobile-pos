# Non-Functional Requirements

> **Status:** 🔵 In review
> **Phase:** 03 — Functional Requirements
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** CTO / QA Lead
> **Approved by:** _pending_

26 requirements (`NFR-001`–`NFR-026`). Every one carries a measurement method — per this phase's
exit criteria, "fast" and "reliable" are not requirements until they are numbers with a way to
check them. Targets are drawn from [success-metrics.md](../01-vision/success-metrics.md) and
[definition-of-done.md](../00-governance/definition-of-done.md); this document is the numbered,
traceable form of both.

Where a pilot and GA target differ, both are stated — the pilot target is the bar for the first
real shops, the GA target is where the product must land before general availability.

---

## Performance

| ID | Requirement | Measurement method |
| --- | --- | --- |
| **NFR-001** | POS screen cold start (launch → ready to scan) completes in p95 ≤ 3 s (pilot) / ≤ 2 s (GA). | Automated performance test on the reference low-end device ([14-testing](../14-testing/README.md)); measured, not estimated. |
| **NFR-002** | Barcode scan → item on screen completes in p95 ≤ 800 ms (pilot) / ≤ 500 ms (GA). | Same as above, against the reference low-end device. |
| **NFR-003** | Product search → result completes in p95 ≤ 400 ms (pilot) / ≤ 250 ms (GA) against a 5,000-item local catalogue. | Automated benchmark with a seeded 5,000-item dataset. |
| **NFR-004** | Local sale commit (payment confirmed → receipt renders) completes in p95 ≤ 300 ms (pilot) / ≤ 200 ms (GA). | Automated performance test, local-only (no network dependency in the measured path). |
| **NFR-005** | API p95 response latency ≤ 400 ms. | Load-test harness in CI/staging; monitored in production via APM. |

## Availability & Synchronisation

| ID | Requirement | Measurement method |
| --- | --- | --- |
| **NFR-006** | Sync success rate (queued operations reaching the server without manual intervention) ≥ 99.5% (pilot) / ≥ 99.9% (GA). | Computed server-side: successful syncs ÷ total queued operations, tracked weekly. |
| **NFR-007** | Sync latency (connectivity restored → queue drained) p95 ≤ 60 s (pilot) / ≤ 30 s (GA). | Client-reported timestamp delta, aggregated server-side. |
| **NFR-008** | Duplicate sale rate = 0. | Automated adversarial sync test suite ([13-offline-sync](../13-offline-sync/README.md)); any non-zero result blocks release. |
| **NFR-009** | Unresolved sync conflicts requiring human resolution ≤ 1 per 1,000 operations (pilot) / ≤ 0.1 per 1,000 (GA). | Counted server-side from the conflict-resolution log. |
| **NFR-010** | API availability ≥ 99.5% monthly. | Uptime monitoring against the production API. |
| **NFR-011** | Crash-free session rate ≥ 99.5%. | Mobile crash reporting, aggregated monthly. |
| **NFR-012** | Crash-free user rate ≥ 99.9%. | Mobile crash reporting, aggregated monthly. |
| **NFR-013** | Sales lost to system failure (attempted but never recorded, for any reason) = 0. | Adversarial test suite plus production incident tracking; this is a release-blocking metric, not merely monitored. |

## Security

| ID | Requirement | Measurement method |
| --- | --- | --- |
| **NFR-014** | Server-side authorisation is enforced on 100% of mutating endpoints, independent of client-side checks. | Automated cross-tenant and cross-role test suite, run on every pull request; zero tolerated failures. |
| **NFR-015** | No secret, API key, or credential is reachable from a client application bundle. | Build-time static check in CI that fails the build if a secret pattern is detected in the client bundle. |
| **NFR-016** | Session tokens are stored only in platform secure storage (Keychain/Keystore-backed), never in shared preferences or plain files. | Code review checklist item plus a static-analysis rule. |
| **NFR-017** | Rate limiting is applied to authentication, sync, and any endpoint capable of enumerating records. | Load test confirming limits trigger correctly; verified per endpoint in [11-api](../11-api/README.md). |
| **NFR-018** | The audit log accepts no update or delete operation through any code path, including administrative tooling. | Automated test attempting modification via every exposed code path; database-level constraint as a second, independent enforcement layer. |
| **NFR-019** | Row Level Security policies exist and pass a cross-tenant negative test for every tenant-scoped table. | Automated RLS test suite, run on every migration in CI; a missing policy fails the build. |

## Accessibility

| ID | Requirement | Measurement method |
| --- | --- | --- |
| **NFR-020** | Colour contrast meets WCAG AA in both light and dark themes. | Automated contrast-ratio check against the design system's token set, plus manual spot-check on real screens. |
| **NFR-021** | All interactive touch targets are ≥ 48 dp. | Automated widget-test assertion on rendered target sizes; design-system component audit. |
| **NFR-022** | No information is conveyed by colour alone. | Design review checklist item, verified against a simulated colour-vision-deficiency rendering. |
| **NFR-023** | Every interactive element carries a screen-reader label. | Automated accessibility audit (e.g. semantics tree check) integrated into widget tests. |

## Device support

| ID | Requirement | Measurement method |
| --- | --- | --- |
| **NFR-024** | The app functions correctly on Android 8.0+ devices with at least 3 GB RAM. | Manual and automated test pass on the reference low-end device, per the ₹13,000–18,000 band identified in [device-landscape.md](../reference/device-landscape.md). Provisional on OD-01; the 2 GB floor in the original founding brief is revised upward based on researched market device data, not assumed. |
| **NFR-025** | The app renders correctly from a 5-inch phone through a 10-inch tablet, in portrait and the orientations each screen supports. | Automated golden-image/widget tests across the breakpoint set defined in [10-design-system](../10-design-system/README.md). |
| **NFR-026** | The app functions correctly under a throttled 3G / weak-4G network profile, not only under a binary online/offline toggle. | Network-conditioning test harness (e.g. simulated latency and packet loss) as part of the offline adversarial suite. |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial 26 non-functional requirements, all with stated measurement methods. |
