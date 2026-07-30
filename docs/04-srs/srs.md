# Software Requirement Specification — SmartPOS X V1

> **Status:** 🔵 In review
> **Phase:** 04 — Software Requirement Specification
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** CTO
> **Approved by:** _pending_

Structure adapted from IEEE 830. **This document, together with the documents it links, is the
binding engineering contract for V1.** Per this phase's rule: if it is not in here or in what it
links to, it is not being built. Changes after approval require a major version bump and
re-approval — no exceptions for "small" changes, because a small change to a binding contract is
still a change to a binding contract.

This document consolidates; it does not duplicate. Where full detail lives in a numbered
requirements document, this SRS gives the summary an engineer needs to orient, and links out for
the rest.

---

## 1. Introduction

### 1.1 Purpose

This SRS is the single authoritative specification for SmartPOS X V1 — the sixteen-module,
offline-first, Android-native point-of-sale platform defined in
[project-vision.md](../01-vision/project-vision.md) and bounded in
[scope-and-release-slices.md](../01-vision/scope-and-release-slices.md). It exists so that "what are
we building" has one answer, reachable from one document, rather than living across conversation
history, chat threads, and memory.

### 1.2 Scope

**In scope for V1:** the sixteen modules listed in §2.2 below, plus the offline synchronisation
engine that makes all of them trustworthy without connectivity. **Out of scope for V1** (deferred,
not cancelled): suppliers/procurement, loyalty/wallet/store-credit/gift-cards, multi-outlet UI,
QR customer ordering, online payment, shipping/delivery, employee management, vertical-specific
features (batch/expiry/serial). **Permanently out of scope**: full accounting, payroll,
manufacturing, holding customer funds, a general e-commerce storefront, iOS at launch, a desktop
application. Full rationale in [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md).

### 1.3 Definitions, acronyms, abbreviations

Not duplicated here — see [GLOSSARY.md](../GLOSSARY.md), which is itself a living document updated
alongside every phase that introduces a new term.

### 1.4 References

| Phase | Document | What it governs |
| --- | --- | --- |
| 00 | [Governance](../00-governance/README.md) | How every phase and every pull request is judged |
| 01 | [Vision](../01-vision/README.md) | Why the product exists, what it will never be, success metrics |
| 02 | [Business Requirements](../02-business-requirements/README.md) | 54 `BR`s, market/regulatory/competitor research, cost model, pricing |
| 03 | [Functional Requirements](../03-functional-requirements/README.md) | 84 `FR`s, 26 `NFR`s, 26 domain rules (`DR`), 28 user stories, full traceability |
| 04 | This document and its four companions | System context, constraints, quality attributes, dependencies |
| — | [ADR register](../adr/README.md) | Every architecturally significant decision made so far |

### 1.5 Overview

§2 describes the product at a level sufficient for orientation. §3 states the specific
requirements by reference, with the additions this phase is responsible for (interface and database
requirements, at the level of detail available before Phases 07/11 exist). §4 states how
verification will work. §5 is the appendix: traceability, decisions, and — importantly — every
place this document is still provisional.

---

## 2. Overall description

### 2.1 Product perspective

SmartPOS X V1 is a standalone Android application backed by a cloud API. It is not a module of a
larger suite and does not require a companion desktop product. Its architecture, summarised:

- **Mobile client** (Flutter): the primary and, for V1, only interface. Offline-first — the local
  Drift SQLite database is authoritative at the point of sale.
- **API** (Next.js on Vercel): the sole path for writes and business logic, per
  [ADR-0001](../adr/ADR-0001-hybrid-api-and-direct-realtime-access.md).
- **Platform** (Supabase): Postgres, Auth, Realtime, Storage — accessed per the hybrid boundary in
  ADR-0001, never as an undifferentiated backend the client talks to freely.

Full actor and boundary detail: [system-context.md](system-context.md).

### 2.2 Product functions — the sixteen V1 modules

| Module | One-line function |
| --- | --- |
| Authentication | Identity, sessions, secure token storage, remote revocation |
| Company & Store Setup | Shop identity, currency, tax-registration status, ten-minute onboarding |
| Roles & Permissions | Cashier / Manager / Owner, enforced server-side |
| Audit Log | Tamper-proof record of every money/stock/permission-affecting action |
| Categories | Single-level product organisation |
| Units | Piece/weight/volume, fractional-quantity support |
| Products | Catalogue with SKU, barcode, HSN/SAC |
| Inventory — Stock Ledger | Append-only movement log; balances always derived |
| Customers (basic) | Name, phone, purchase history |
| POS | Scan/search → cart → payment → receipt, offline-capable, tap-count budgeted |
| Sales & Invoices | Immutable completed sales; GST-compliant invoicing |
| Receipt & Printing | Bluetooth ESC/POS printing with a digital-share fallback |
| Returns & Refund (basic) | Return by receipt/invoice/phone, partial or full, approval above threshold |
| Cash Drawer / Day Close | Float, reconciliation, variance flagging |
| Reports (core four) | Daily sales, stock value, top/slow products, low stock |
| Settings | Tax, currency, printer, receipt configuration |

Plus the **Offline Synchronisation Engine** — cross-cutting, not a screen a user navigates to, but
a required subsystem underpinning every module above.

Full requirement-level detail: [business-requirements.md](../02-business-requirements/business-requirements.md),
[functional-requirements.md](../03-functional-requirements/functional-requirements.md).

### 2.3 User characteristics

Actor summary in [system-context.md §1](system-context.md#1-human-actors). **Phase 05 has not yet
run** — persona detail here is provisional, drawn from the founding brief and Phase 02/03 research,
not yet validated against real shop interviews. The Cashier persona is load-bearing for POS design:
under queue pressure, possibly untrained, possibly temporary — see
[project-vision.md §5](../01-vision/project-vision.md).

### 2.4 Constraints

Headline items — full list in [constraints.md](constraints.md):

- Android-first, Android 8.0+, ≥3 GB RAM reference floor.
- Offline-first is architectural, not a feature — the local database is authoritative at the point
  of sale.
- Money as integer minor units everywhere; stock as an append-only signed-delta ledger. Both
  non-negotiable, both binding on Phase 07.
- Mobile client never writes business data directly (ADR-0001).
- Every store-scoped record carries `store_id` from the first migration (ADR-0003).
- Permissive-licence dependencies only; free hosting tiers for dev/pilot, paid tier from commercial
  launch (ADR-0002).

### 2.5 Assumptions and dependencies

Full catalogue in [assumptions-and-dependencies.md](assumptions-and-dependencies.md). The two
headline assumptions still open: **the launch market (OD-01) is provisionally India, unconfirmed**,
and **the GST research behind RR-001–RR-008 has not yet had a qualified-practitioner review**. Both
are load-bearing for the tax/invoicing requirements and are flagged everywhere they apply, not just
here.

### 2.6 Apportioning of requirements

All 54 `BR`s and 84 `FR`s in this SRS are **V1-scoped** — see the traceability and module-coverage
tables in [traceability-matrix.md](../03-functional-requirements/traceability-matrix.md). Nothing in
V2–V4 is specified at requirement level yet; those modules will get their own `BR`/`FR` sets when
their phase starts, per the "one module at a time" rule.

---

## 3. Specific requirements

### 3.1 Functional requirements

54 business requirements, decomposed into 84 functional requirements across the sixteen modules
plus the sync engine. **Not duplicated here** — see
[business-requirements.md](../02-business-requirements/business-requirements.md) and
[functional-requirements.md](../03-functional-requirements/functional-requirements.md). Every `FR`
states its own offline behaviour inline; there is no separate "offline requirements" section because
offline is not a mode bolted onto requirements, it is a property most of them must have.

### 3.2 Non-functional / quality requirements

26 `NFR`s (performance, availability/sync, security, accessibility, device support), each with a
measurement method — see
[non-functional-requirements.md](../03-functional-requirements/non-functional-requirements.md).
Ten quality-attribute scenarios (stimulus → environment → response → measure), one level more
concrete than the NFRs — see [quality-attributes.md](quality-attributes.md).

### 3.3 External interface requirements

Actors and systems: [system-context.md §1–2](system-context.md). Trust boundaries and their
enforcement: [system-context.md §4](system-context.md#4-trust-boundaries--the-list-phase-12-inherits).
**The detailed API contract itself (endpoints, request/response schemas, error codes) is Phase 11's
deliverable and does not exist yet** — this SRS fixes the *shape* of the interface (API-only writes,
RLS-gated realtime reads, signed-URL file transfer) without yet fixing its *content*.

### 3.4 Database requirements

**The schema itself is Phase 07's deliverable and does not exist yet.** This SRS fixes three
constraints Phase 07 must satisfy, already decided and binding, not open for reconsideration at
that phase:

1. Stock is represented as an append-only ledger of signed deltas; a balance is always derived, never
   stored as an independently writable value (DR-001, DR-002).
2. Money is stored as an integer count of the currency's minor unit, with no floating-point
   representation anywhere in the pipeline (DR-010).
3. Every store-scoped table carries a non-null `store_id` from its first migration (ADR-0003).

The still-open multi-tenancy model decision (shared schema vs. schema-per-tenant) has a strong
data-driven finding pointing toward shared schema — see
[cost-model.md §4](../02-business-requirements/cost-model.md) — but remains formally open in the
[ADR backlog](../adr/README.md) until Phase 07 ratifies it.

### 3.5 Domain / business rules

26 rules (`DR-001`–`DR-026`) covering stock, tax/money, returns eligibility, permissions,
sync/idempotency, and audit — each stated in a form that becomes a unit test verbatim. See
[business-rules.md](../03-functional-requirements/business-rules.md). These rules, not any UI
screen, are where the domain is actually defined.

### 3.6 Design constraints

Full list: [constraints.md](constraints.md). These bind Phase 08 (folder structure), Phase 10
(design system), and Phase 15 (CI/CD) specifically.

---

## 4. Verification

**Phase 14 (Testing Strategy) has not yet run** and owns the full verification plan. What this SRS
guarantees in the meantime: every `FR` is independently testable by construction (behaviour, not
interface, stated atomically); every `NFR` carries a measurement method; every `DR` carries an
assert-form statement. This is what makes Phase 14 possible to write well rather than invented from
nothing — the testability was designed in at Phase 03, not retrofitted at Phase 14.

---

## 5. Appendices

### Appendix A — Traceability

Full `BR → FR → US` matrix and per-module coverage check:
[traceability-matrix.md](../03-functional-requirements/traceability-matrix.md). Headline fact: 54/54
business requirements have at least one functional requirement; zero functional requirements are
orphaned from a business requirement.

### Appendix B — Decision register

Three ADRs accepted so far ([ADR-0001](../adr/ADR-0001-hybrid-api-and-direct-realtime-access.md),
[ADR-0002](../adr/ADR-0002-hosting-posture-for-commercial-launch.md),
[ADR-0003](../adr/ADR-0003-multi-outlet-modelled-from-day-one.md)), governing the API access
pattern, hosting posture, and store-scoping respectively. Twelve further decisions are tracked as an
open backlog in [docs/adr/README.md](../adr/README.md), each tagged with the phase that forces it —
nothing on that backlog blocks Phase 04, but several block Phase 07.

### Appendix C — Open items (read this before treating anything above as final)

| Item | Affects | Status |
| --- | --- | --- |
| [OD-01](../01-vision/open-decisions.md) — launch market | All tax/regulatory content (§2.4, §2.5, §3.1's RR-linked FRs) | Provisional: India assumed, unconfirmed |
| GST-practitioner review | [RR-001–RR-008](../02-business-requirements/regulatory-requirements.md) and every FR/DR tracing to them | Not yet done — blocks compliance claims, not engineering design |
| [OD-06](../01-vision/open-decisions.md) — time capacity | Phase 16 milestones only | Open, non-blocking until then |
| Pilot willingness-to-pay validation | [pricing-strategy.md](../02-business-requirements/pricing-strategy.md) | Recommendation stands, unvalidated |
| Realtime-outage fallback behaviour | [assumptions-and-dependencies.md](assumptions-and-dependencies.md) | Open question for Phase 13, not yet resolved |
| Local-storage-full behaviour | [assumptions-and-dependencies.md](assumptions-and-dependencies.md) | Open question for Phase 13, not yet resolved |
| Multi-tenancy model ratification | [constraints.md](constraints.md) §Technical | Strong finding exists (shared schema); formal ADR due at Phase 07 |

**None of these block starting Phase 05.** They are listed here, consolidated, so nobody has to
reconstruct "what's still soft" by reading six documents — this appendix is that reconstruction,
done once.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial SRS consolidating Phases 01–03, plus system context, constraints, quality attributes, and dependencies from this phase. |
