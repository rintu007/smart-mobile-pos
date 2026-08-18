# Test Strategy

> **Status:** 🔵 In review
> **Phase:** 14 — Testing Strategy
> **Version:** 0.2.0
> **Last updated:** 2026-08-19
> **Owner:** QA Lead / CTO
> **Approved by:** _pending_

Levels, ownership, coverage targets, and what is deliberately not automated — and, per this phase's
first exit criterion, the complete traceability from every one of Phase 03's 26 business rules to
at least one automated test. This document does not re-derive test *cases* already fully specified
elsewhere (Phase 12's threat model, Phase 13's adversarial suite) — it is the index that proves
nothing was missed, plus the policy that governs everything not already covered by name.

---

## 1. Business-rule traceability — the exit criterion, made checkable

| Rule | Covered by |
| --- | --- |
| DR-001 (balance = Σ deltas) | [stock-ledger.md](../07-database/stock-ledger.md)'s proof; [test-plan.md §2](../13-offline-sync/test-plan.md#2-concurrent-composition-tests)'s concurrent/fuzz tests |
| DR-002 (movements never updated/deleted) | Schema grant test — attempt an `UPDATE`/`DELETE` against `stock_movements` with the service-role credential, assert rejection (a negative DB-level test, not an application-level one) |
| DR-003, DR-004 (sale/return produce exactly one movement) | Unit test on `sales`/`returns` service methods, asserting movement count == 1 per completed line |
| DR-005 (oversell permitted) | [stock-ledger.md §4](../07-database/stock-ledger.md#4-worked-example--two-devices-selling-concurrently-offline)'s worked example, asserted as a unit test |
| DR-006 (opening establishes first balance) | Unit test — balance before any opening movement is undefined/zero by convention, asserted explicitly |
| DR-007 (adjustment requires reason) | Unit + schema `CHECK`-constraint test (both layers, per [input-validation.md](../12-security/input-validation.md)'s defence-in-depth stance) |
| DR-008 (tax rounding per line) | Unit tests against [money-and-tax.md](../07-database/money-and-tax.md)'s worked examples (`pos/service.test.ts`) — **not** the property-based test (§4) originally claimed here; that suite doesn't exist yet, found Sprint 42 (backlog.md M4 item 7), corrected rather than left overstating coverage |
| DR-009 (Composition/unregistered shows no tax breakdown) | Unit test on receipt/invoice rendering logic per `tax_registration_type_at_sale` |
| DR-010 (money as integer minor units, always) | A static lint rule banning `Float`/`Double` types on any field named `*_minor_units` or `*_amount` — a structural test, not a runtime one |
| DR-011, DR-012 (discount shape, auto-approval threshold) | Unit tests, both branches (at/below/above threshold) |
| DR-013, DR-014, DR-015, DR-016 (return quantity/refund/threshold/one-sale rules) | Unit tests per rule (`returns/service.test.ts`) — **not** property-tested (§4) against randomised partial-return sequences as originally claimed here; same Sprint 42 correction as DR-008 above |
| DR-017, DR-018 (server-side permission re-check at sync, full rejection) | [authorisation-model.md](../12-security/authorisation-model.md)'s 7-step order, tested per step; [failure-scenarios.md §2](../13-offline-sync/failure-scenarios.md#2-resolving-finding-1--provisional-approvals-rejected-after-the-fact)'s Finding 1 scenario as an integration test |
| DR-019, DR-020, DR-021 (role permission sets) | [permission-matrix.md](../05-personas/permission-matrix.md)'s full 16×3 matrix, each cell an authorisation unit test — 48 assertions, not sampled |
| DR-022 (idempotency key on every mutation) | [idempotency.md §3](../13-offline-sync/idempotency.md#3-proof--replaying-the-entire-queue-twice-produces-identical-state)'s proof; [test-plan.md §1](../13-offline-sync/test-plan.md#1-idempotent-replay-tests) |
| DR-023 (delta never adjusted/scaled) | Same as DR-002 — a grant-level test, not merely an application-level assertion |
| DR-024 (provisional invoice number permanent) | Unit test — attempt to alter a synced sale's `provisional_invoice_number`, assert rejection |
| DR-025 (audit entry for every money/stock/permission action) | Integration test — perform each named action category, assert exactly one corresponding `audit_log` row |
| DR-026 (no path can alter/delete audit) | Same grant-level test pattern as DR-002/DR-023, applied to `audit_log` |

**All 26 rules map to at least one named, automated test above — this phase's first exit criterion,
closed by inspection of this table, not by a separate claim.** Rules with a shared test shape
(DR-002/DR-023/DR-026, the three grant-level append-only guarantees) are grouped for clarity, not
merged into fewer actual test cases — each table still gets its own dedicated test.

## 2. Levels and ownership

| Level | Owns | Runs against |
| --- | --- | --- |
| Unit | Business rules in `service.ts` (backend) and the equivalent Dart domain layer (mobile) — the DR-NNN rules above | No I/O — pure functions, in-memory fakes only |
| Widget (Flutter) | Individual screen/component behaviour against [10-design-system](../10-design-system/README.md)'s states | Flutter's widget-test harness, no real device |
| Integration | Repository↔Prisma against a real test Postgres; Drift repository against a real local SQLite; the sync engine's contract against a real (test) API instance | Real database, real (test) network |
| End-to-end | A full user workflow, device (or emulator) to server | The reference low-end device ([device-matrix.md](device-matrix.md)) or CI-hosted emulator, against a staging API |

## 3. Coverage targets

Per [success-metrics.md](../01-vision/success-metrics.md)'s own engineering-health metric: **≥90%
branch coverage on domain/business logic, UI excluded from the target entirely.** This is a
deliberate, asymmetric target, not an oversight — per this phase's rule, 90% coverage achieved by
testing getters is worth less than 90% coverage concentrated on the code that computes money and
stock. A pull request that raises overall coverage by adding UI snapshot tests while a service
method's failure branch remains untested does not satisfy this target's intent, even if the raw
percentage looks acceptable.

## 4. Property-based testing — money and stock, not only worked examples (never built — corrected Sprint 42)

Per this phase's rule, [money-and-tax.md](../07-database/money-and-tax.md)'s and
[stock-ledger.md](../07-database/stock-ledger.md)'s worked examples become **fixed regression
cases** inside a property-based suite that additionally generates randomised inputs (random prices,
tax rates, discount percentages, quantities, and — for stock — randomised operation interleavings
across simulated devices) and asserts the *invariant*, not a specific expected number: tax + subtotal
− discount always equals the grand total to the last minor unit; a stock balance is always exactly
`Σ quantity_delta` regardless of application order. This is what catches the input the original
worked example didn't happen to think of, per this phase's own stated rationale.

**Found Sprint 42 (backlog.md M4 item 7), while building `nightly.yml`'s "extended property-based
run" row: no such suite exists at all, on any tier.** No property-based testing library (`fast-check`
or equivalent) is a dependency anywhere in `apps/web`; §1's table above had been citing this section
for DR-008/DR-013 coverage since this document's first version, without the suite ever having been
written — a stale claim, not a lie discovered maliciously, but a real gap between this document and
the code exactly like Sprint 40/41's own findings in adjacent phases. The stock-order-independence
half of this section's intent **is** covered, just not by a property-based suite here — Sprint 41's
`sync-concurrent-composition.nightly.test.ts` (100 randomised device-interleaving runs) proves the
same invariant this section describes, against a real database, for the sync-engine path
specifically. The money-invariant half (tax + subtotal − discount = grand total, across randomised
inputs) remains genuinely unbuilt — real, tracked scope for whenever it's next prioritised, not
silently implied as already solved by this document's own §1 table.

## 5. What is deliberately not automated

Physical printer output (ESC/POS dialect variation, per [device-landscape.md](../reference/device-landscape.md)),
real barcode-scanner behaviour under real lighting conditions, and a full real trading day on real
hardware are **scripted manual tests** ([manual-test-scripts.md](manual-test-scripts.md)), not
automated — per this phase's rule, "manual" here means scripted and evidenced, never "tried it and
it seemed fine." Automating a Bluetooth thermal printer interaction reliably in CI is disproportionate
effort for a V1 product at this scale; the risk it protects against is real but is better closed by
a scripted human check before every release than by a brittle hardware-in-the-loop CI rig this team
does not yet have the capacity to maintain.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Full 26-rule business-rule traceability table; levels/ownership; 90%-on-domain-logic coverage target explained; property-based testing scope; manual-vs-automated boundary justified. |
| 0.2.0 | 2026-08-19 | Sprint 42 (backlog.md M4 item 7) found §4's property-based suite was never built at all (no property-testing library anywhere in `apps/web`) — §1's DR-008/DR-013 rows corrected to the real unit-test coverage that does exist, rather than continuing to claim a nonexistent suite; §4 itself corrected to name this as a real, tracked gap, with the stock-order-independence half noted as separately covered by Sprint 41's fuzzed sync-engine test. |
