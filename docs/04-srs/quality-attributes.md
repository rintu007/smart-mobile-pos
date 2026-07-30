# Quality Attributes

> **Status:** 🔵 In review
> **Phase:** 04 — Software Requirement Specification
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** CTO / QA Lead
> **Approved by:** _pending_

Ten scenarios (`QA-001`–`QA-010`), each in the standard **stimulus → environment → response →
measure** form. This is a stricter test than [non-functional-requirements.md](../03-functional-requirements/non-functional-requirements.md):
an NFR gives a target number; a quality-attribute scenario describes the concrete situation that
number has to survive. Where an NFR/DR already sets the number, this document does not repeat it —
it names which one applies.

---

**QA-001 — Performance (scan latency)**
| | |
| --- | --- |
| Stimulus | Cashier scans a product's barcode with the device camera. |
| Environment | Reference low-end device, foreground app, local catalogue of 5,000 items, any connectivity state. |
| Response | The matching product is added to the active cart at quantity 1. |
| Measure | p95 ≤ 800 ms (pilot) / ≤ 500 ms (GA) — [NFR-002](../03-functional-requirements/non-functional-requirements.md). |

**QA-002 — Reliability (sale survives connectivity loss)**
| | |
| --- | --- |
| Stimulus | Network connectivity drops at the instant payment is confirmed. |
| Environment | POS screen mid-transaction, cart with one or more line items, device otherwise healthy. |
| Response | The sale completes normally — no error shown, no retry prompt, stock decremented locally, receipt available. |
| Measure | 0 sales lost to system failure, verified by the adversarial sync test suite — [NFR-013](../03-functional-requirements/non-functional-requirements.md), [BR-003](../02-business-requirements/business-requirements.md)/[BR-004](../02-business-requirements/business-requirements.md). |

**QA-003 — Reliability (extended offline recovery)**
| | |
| --- | --- |
| Stimulus | Connectivity is restored after 5 consecutive offline trading days at normal volume. |
| Environment | Device holds a full multi-day operation queue; server has not seen this device in that window. |
| Response | The queue drains completely; every operation is applied exactly once; no operation is silently dropped. |
| Measure | Sync success rate ≥ 99.5% (pilot); duplicate-sale rate = 0 — [NFR-006](../03-functional-requirements/non-functional-requirements.md), [NFR-008](../03-functional-requirements/non-functional-requirements.md), [FR-084](../03-functional-requirements/functional-requirements.md). |

**QA-004 — Security (tenant isolation holds under a direct attempt)**
| | |
| --- | --- |
| Stimulus | An authenticated user of Tenant A requests or subscribes to a record scoped to Tenant B (e.g. by guessing or enumerating an identifier). |
| Environment | Production API (TB-1) and Realtime (TB-2) both active, per [system-context.md](system-context.md). |
| Response | The request is rejected or returns an empty result at **both** boundaries independently; the attempt is logged as an anomaly. |
| Measure | 100% rejection across the automated cross-tenant test suite, run on every migration; 0 tolerated failures — [NFR-014](../03-functional-requirements/non-functional-requirements.md), [NFR-019](../03-functional-requirements/non-functional-requirements.md). |

**QA-005 — Security (lost-device containment)**
| | |
| --- | --- |
| Stimulus | An Owner reports a device lost or stolen and revokes its session from another device. |
| Environment | The lost device was previously authenticated and may still have connectivity. |
| Response | The revoked device is blocked at its next sync or API call attempt; no further data can be pushed or pulled from it. |
| Measure | Revocation takes effect within one connectivity window of the revoked device's next contact attempt — [BR-005](../02-business-requirements/business-requirements.md), [FR-014](../03-functional-requirements/functional-requirements.md). Full mitigation is bounded, not absolute — see [R-09](../01-vision/risks-constraints-assumptions.md); unsynced data already on the device before revocation is not itself recoverable by this mechanism. |

**QA-006 — Maintainability (a new engineer's first change)**
| | |
| --- | --- |
| Stimulus | A new engineer is asked to add a field to the Products module. |
| Environment | Only the repository and `docs/` are available — no verbal handoff. |
| Response | The engineer locates the correct module specification, schema location, and API contract to change, unassisted. |
| Measure | Directional target, not yet an enforced gate: first correct, reviewable pull request for a well-scoped change within 1 working day. Revisit once real onboarding data exists — this scenario exists to keep documentation quality honest, not to be gamed. |

**QA-007 — Accessibility (text scaling)**
| | |
| --- | --- |
| Stimulus | A user sets the OS system text scale to 130%, then 200%. |
| Environment | POS screen and Reports screen, default theme, both light and dark. |
| Response | All text remains legible with no truncation or overlap; every touch target remains ≥ 48 dp. |
| Measure | Verified by golden-image/widget test at 130%; manual check at 200% — [NFR-021](../03-functional-requirements/non-functional-requirements.md), [NFR-023](../03-functional-requirements/non-functional-requirements.md). |

**QA-008 — Usability (tap-count budget)**
| | |
| --- | --- |
| Stimulus | Cashier scans a single item for a straight cash sale. |
| Environment | Reference low-end device, POS screen, no discounts or split payment involved. |
| Response | Sale completes and receipt is available. |
| Measure | ≤ 3 discrete user actions, p95 latency budgets per [NFR-001](../03-functional-requirements/non-functional-requirements.md)/[NFR-002](../03-functional-requirements/non-functional-requirements.md)/[NFR-004](../03-functional-requirements/non-functional-requirements.md) — [BR-011](../02-business-requirements/business-requirements.md). |

**QA-009 — Portability (vendor exit is a project, not a crisis)**
| | |
| --- | --- |
| Stimulus | A decision is made to migrate off Supabase and/or Vercel due to a pricing, licence, or policy change. |
| Environment | Production system with live tenant data; decision made with no advance notice from the vendor. |
| Response | Migration proceeds as a scheduled project — standard PostgreSQL dump/restore, containerised API redeployment — with no business-logic rewrite required. |
| Measure | Zero changes required outside the infrastructure-adapter layer; verified by the "no vendor-proprietary primitive in domain code" review rule — [ADR-0002](../adr/ADR-0002-hosting-posture-for-commercial-launch.md). |

**QA-010 — Data integrity (tax rounding is exact under composition)**
| | |
| --- | --- |
| Stimulus | A sale contains 3+ line items at differing tax rates, under a shop-configured rounding rule. |
| Environment | Any device, online or offline; any supported tax mode (standard/Composition/unregistered). |
| Response | Each line's tax is computed and rounded independently, then summed for the invoice total. |
| Measure | Invoice total tax exactly equals the sum of rounded per-line tax values across a property-based test sweep, 100% of generated cases — [DR-008](../03-functional-requirements/business-rules.md). |

---

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial 10 quality-attribute scenarios covering performance, reliability, security, maintainability, accessibility, usability, portability, and data integrity. |
