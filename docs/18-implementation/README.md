# Phase 18 — Implementation

> **Status:** 🟡 In progress — Sprint 01 through Sprint 11 all closed; M0 items 8–11 remain, next up
> **Version:** 0.13.0
> **Last updated:** 2026-08-13
> **Owner:** CTO / All engineering roles

## Charter

| | |
| --- | --- |
| **Objective** | Build SmartPOS X, one complete module at a time, against approved specifications. |
| **Inputs** | Approved Phases 01–17. |

## The module loop

Every module, without exception, follows this sequence:

```
1. Author the module specification in docs/modules/<module>/  (all 11 sections)
2. Review and approve the specification
3. Write the database migration and Row Level Security policies
4. Implement the API: validation → service → repository
5. Write API tests, including authorisation and cross-tenant isolation
6. Implement the local schema and the offline queue behaviour
7. Implement the domain layer and its unit tests
8. Implement the interface and its widget tests
9. Write the integration test for the primary end-to-end workflow
10. Write the offline → online sync test, including a conflict
11. Verify against the Definition of Done — every box
12. Update all affected documentation
13. Merge
```

**Steps are not reordered and none are skipped.** In particular, the specification is written
before the code, not reverse-engineered from it afterwards.

## Deliverables

| Document | Content |
| --- | --- |
| `implementation-log.md` | Module-by-module record: dates, decisions, deviations, lessons |
| `coding-standards.md` | Dart and TypeScript conventions, lint configuration, formatting |
| `error-handling.md` | Error taxonomy, propagation, user-facing messages, logging and redaction |
| `performance-playbook.md` | Query patterns, list virtualisation, image handling, startup budget |
| `troubleshooting.md` | Known issues and their resolutions, grown as we encounter them |

## Module build order

Ordered so that each module can be genuinely completed and demonstrated using only what precedes
it. The order is fixed at Phase 16 against the dependency graph and recorded in
[docs/modules/README.md](../modules/README.md).

The **first** module is always the vertical slice from Phase 16: authenticate → add a product →
sell offline → sync → print. It touches every architectural layer while changing course is still
cheap.

## Exit criteria per module

The [Definition of Done](../00-governance/definition-of-done.md), in full. There is no partial credit.

## Rules

- **No placeholder code.** No `TODO`, no stub, no "wire this up later". A module that is not
  finished is not merged.
- **No module starts before the previous one is done.** Parallel half-modules produce integration
  debt that is paid at the worst time.
- **Deviations from the specification update the specification** — in the same pull request, with
  the reasoning. The documentation is the source of truth; silent divergence ends that.
- **Every implementation-time decision of consequence becomes an ADR.** If you had to think about
  it for more than ten minutes, someone will have to think about it again later.

## Where things stand

Sprint 01 ([docs/17-sprints/sprint-01.md](../17-sprints/sprint-01.md)) is the repository/tooling
scaffold that precedes the first module in the loop above — not a module itself, so it is not held
to the 13-step loop or the full Definition of Done. See
[implementation-log.md](implementation-log.md) for what has actually landed.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Status moved to in-progress: Sprint 01 (repository scaffold, Supabase Auth wiring) underway. |
| 0.2.0 | 2026-08-01 | Sprint 01 closed: branch protection live, CI actually exercised and green on a merged PR, Identity/Auth demoed end-to-end on real infrastructure. Next up is Sprint 02 planning for the first real module. |
| 0.3.0 | 2026-08-01 | Sprint 02 planned. First closed a real gap found while planning it: Authentication and Company & Store Setup had no approved module specifications (the former despite already having live Sprint 01 code), and Phase 11 had never specified the signup/onboarding endpoint at all. |
| 0.4.0 | 2026-08-01 | Sprint 02 closed: `POST /api/v1/onboarding` built and demoed live, all 6 demo steps passed against the real database. Next up is Sprint 03 planning. |
| 0.5.0 | 2026-08-01 | Sprint 03 closed: Flutter SDK installed, `apps/mobile` scaffolded and reshaped to `mobile-structure.md`, local Drift database built for backlog.md item 4 and verified via `flutter test` (schema opens, all five tables round-trip). Unblocks every remaining M0 backlog item, which all depended on this. Next up is Sprint 04 planning. |
| 0.6.0 | 2026-08-01 | Sprint 04 closed: `POST /api/v1/products` built and demoed live against real infrastructure, including a cross-tenant RLS proof. Found and fixed a real, three-sprints-latent bug in `requireSession`. Next up is Sprint 05 planning. |
| 0.7.0 | 2026-08-02 | Sprint 05 closed: `POST /api/v1/sales` built and demoed live with server-side price/payment recompute and a cross-tenant RLS proof. No new bug found. Flagged the three-sprints-running mobile-UI deferral as a risk for Sprint 06 to weigh directly. Next up is Sprint 06 planning. |
| 0.8.0 | 2026-08-02 | Sprint 06 closed: mobile `/auth/login` — the first real Flutter screen — built, tested, and verified live against real Supabase Auth. Closed the mobile-UI-deferral risk's first concrete slice and a real backlog gap (mobile sign-in was never decomposed). Next up is Sprint 07 planning. |
| 0.9.0 | 2026-08-02 | Sprint 07 closed: mobile product creation (`/catalogue/add`) built, tested, and verified against a real on-disk file across a fresh connection. Closed backlog item 5's remaining mobile scope. Next up is Sprint 08 planning. |
| 0.10.0 | 2026-08-02 | Sprint 08 closed: `GET /api/v1/stores` built and verified live with a cross-tenant RLS proof; mobile fetch-and-cache built — the till screen's real prerequisite, found during planning rather than assumed. Next up is Sprint 09 planning (the till screen itself). |
| 0.11.0 | 2026-08-02 | Sprint 09 closed: mobile till screen (`/pos`) built and tested against a real Drift database — cart, cash-only sale completion, an atomic multi-row local write (`sales`/`sale_line_items`/`sale_payments`/`outbound_queue`), and ADR-0008's local invoice-numbering half. Server endpoint (Sprint 05) and mobile write path proven independently; the sync engine that connects them (item 9) remains unbuilt. Next up is Sprint 10 planning. |
| 0.12.0 | 2026-08-12 | Sprint 10 closed: mobile sales-history list/detail (`/sales-history`) built — a founder-directed insertion of Sales & Invoices' minimal local-read slice, triggered by the founder's own first hands-on test of the till screen on a real device. New module specification written first. Also: first real (non-demo, non-deleted) founder account created and the app installed on the founder's own phone for the first time this project — a genuine milestone distinct from every prior sprint's throwaway live-verification pattern. M0 items 7–11 remain open next. |
| 0.13.0 | 2026-08-13 | Sprint 11 closed: M0 item 7 (stock ledger) built — `POST /api/v1/products` and `POST /api/v1/sales` each write their stock movement (`opening`, `sale`) inside the same transaction as their triggering row. New module specification (`inventory/specification.md`) written first. Live-verified against the real database with throwaway tenants: opening/replay idempotency, a real oversell proving DR-005, and a cross-tenant RLS proof on `stock_movements` itself — 16/16 checks passed. Closes the gap both `products` and `pos` specifications had named since Sprint 04/05. M0 items 8–11 remain open next. |
