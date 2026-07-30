# Constraints

> **Status:** 🔵 In review
> **Phase:** 04 — Software Requirement Specification
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** CTO
> **Approved by:** _pending_

Consolidates constraints already established across Phases 00–03 into one place, organised by
type, so nothing is re-derived or accidentally contradicted in Phase 07 onward. Where a constraint
was set elsewhere, this document links to it rather than restating the reasoning — only the
constraint itself and its source are given here.

---

## Technical constraints

| Constraint | Source | Note |
| --- | --- | --- |
| Flutter (stable channel), Material 3, Riverpod, Go Router, Drift SQLite, Flutter Secure Storage | Founding brief | Mobile stack, fixed. |
| Next.js (App Router), TypeScript, Prisma, Zod | Founding brief | Backend stack, fixed. |
| PostgreSQL via Supabase; Supabase Auth, Storage, Realtime | Founding brief; [ADR-0001](../adr/ADR-0001-hybrid-api-and-direct-realtime-access.md) | Platform, fixed for V1. |
| Android 8.0+, minimum 3 GB RAM | [NFR-024](../03-functional-requirements/non-functional-requirements.md) | **Revises** the founding brief's original 2 GB figure upward, based on researched current device pricing/spec data in [device-landscape.md](../reference/device-landscape.md) — not a silent contradiction, a deliberate, sourced correction. |
| No card-network integration, no payment-holding, no custom payment rail | [project-vision.md §6](../01-vision/project-vision.md) | We integrate a licensed gateway; we are not one. |
| Mobile client never writes business data directly — API-only for writes, direct access only for realtime reads and signed-URL file transfer | [ADR-0001](../adr/ADR-0001-hybrid-api-and-direct-realtime-access.md) | Binding on every module's implementation. |
| Every store-scoped table carries a non-null `store_id` from the first migration | [ADR-0003](../adr/ADR-0003-multi-outlet-modelled-from-day-one.md) | Binding on Phase 07 schema design. |
| Money stored as integer minor units everywhere in the pipeline; never floating-point | [DR-010](../03-functional-requirements/business-rules.md) | Binding on Phase 07 schema and all calculation code. |
| Stock is an append-only ledger of signed deltas; balances are always derived, never stored | [DR-001](../03-functional-requirements/business-rules.md) | Binding on Phase 07 schema. |
| Shared-schema, row-level tenant scoping (not schema-per-tenant) | [cost-model.md §4](../02-business-requirements/cost-model.md) | Strong finding, not yet a formal ADR — Phase 07 must ratify or explicitly override with justification. |

## Regulatory constraints

**All entries below are provisional on [OD-01](../01-vision/open-decisions.md)** — assumed India,
unconfirmed. If the launch market changes, this entire section is replaced.

| Constraint | Source |
| --- | --- |
| Tax invoices require GSTIN, sequential gapless invoice numbering, per-line HSN/SAC and tax breakup | [RR-002](../02-business-requirements/regulatory-requirements.md), [RR-003](../02-business-requirements/regulatory-requirements.md) |
| Composition-scheme/unregistered shops must issue a Bill of Supply, not a Tax Invoice, with no input-credit breakup | [RR-001](../02-business-requirements/regulatory-requirements.md) |
| Tax is computed and rounded per line item, never once on the invoice total | [RR-004](../02-business-requirements/regulatory-requirements.md) |
| Payment-instrument data localisation and payment-system-operator obligations belong to the integrated gateway, not us | [RR-007](../02-business-requirements/regulatory-requirements.md) |
| No compliance claim is made to a customer before a qualified GST practitioner reviews the actual invoice/receipt template | [regulatory-requirements.md — open items](../02-business-requirements/regulatory-requirements.md#open-items-before-this-document-can-be-finalised-blocks--approval) | **Currently unmet — blocks 🟢 approval of Phases 02–04.** |

## Operational constraints

| Constraint | Source |
| --- | --- |
| Monorepo; one module fully complete (spec → schema → API → tests → docs) before the next begins | [ways-of-working.md](../00-governance/ways-of-working.md), [18-implementation](../18-implementation/README.md) |
| No merged code without documentation updated in the same pull request | [documentation-standards.md §6](../00-governance/documentation-standards.md) |
| Small team, long horizon — boring/proven technology preferred over novel | [project-vision.md §8](../01-vision/project-vision.md) |
| Weekly time capacity not yet known | [OD-06](../01-vision/open-decisions.md) | Non-blocking until Phase 16. |

## Licence constraints

| Constraint | Source |
| --- | --- |
| Dependencies must be MIT, BSD, or Apache-2.0 licensed — no GPL/AGPL | [ways-of-working.md §7](../00-governance/ways-of-working.md) |
| Vercel Hobby tier is contractually non-commercial-use-only; commercial launch requires Pro or self-host | [ADR-0002](../adr/ADR-0002-hosting-posture-for-commercial-launch.md), [vendor-limits.md](../reference/vendor-limits.md) |
| Public OpenStreetMap community tile servers are not licensed for commercial-scale use | [vendor-limits.md](../reference/vendor-limits.md) | Applies to V3 only. |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial consolidation from Phases 00–03. |
