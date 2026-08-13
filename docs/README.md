# SmartPOS X — Documentation

> **The Complete Mobile First Business Management Platform.**

This folder is the **single source of truth** for SmartPOS X. Code follows documentation, never
the reverse. If code and documentation disagree, that is a defect in one of them and it is fixed
in the same pull request.

---

## How to use this documentation

| If you want to… | Read |
| --- | --- |
| Understand what we are building and why | [01 — Project Vision](01-vision/) |
| Understand how we work and what "done" means | [00 — Governance](00-governance/) |
| Understand why a technical choice was made | [Architecture Decision Records](adr/) |
| Look up a term | [Glossary](GLOSSARY.md) |
| See what is built and what is not | [Module Registry](modules/) |

---

## Phase map

Phases run in order. **No phase is skipped.** A phase is not started until the previous phase is
approved. Each phase folder contains a `README.md` charter defining its objective, inputs,
deliverables and exit criteria.

| # | Phase | Folder | Status |
| --- | --- | --- | --- |
| 01 | Project Vision | [01-vision](01-vision/) | 🟢 Approved (OD-01 launch market provisional — see [open-decisions.md](01-vision/open-decisions.md)) |
| 02 | Business Requirements | [02-business-requirements](02-business-requirements/) | 🔵 In review — 54 BRs drafted; blocked from 🟢 only by GST-practitioner review and OD-01 confirmation |
| 03 | Functional Requirements | [03-functional-requirements](03-functional-requirements/) | 🔵 In review — 84 FRs, 26 NFRs, 26 domain rules, 28 user stories drafted |
| 04 | Software Requirement Specification | [04-srs](04-srs/) | 🔵 In review — SRS, system context (7 trust boundaries), constraints, quality attributes, dependencies all drafted |
| 05 | User Personas | [05-personas](05-personas/) | 🟡 Draft — hard-blocked on real shop interviews, not just research (see phase notes) |
| 06 | Business Workflows | [06-workflows](06-workflows/) | 🔵 In review — 13 V1 workflows, 4 exhaustive state machines, 3 findings flagged for Phase 13 |
| 07 | Database Design | [07-database](07-database/) | 🔵 In review — 22 tables, 6 ADRs accepted, stock-ledger correctness proven on paper |
| 08 | Folder Structure | [08-folder-structure](08-folder-structure/) | 🔵 In review — layering rules, CI-enforced, both apps mapped to Phase 07's schema |
| 09 | Navigation | [09-navigation](09-navigation/) | 🔵 In review — 42 routes mapped, tap-count audit found and fixed 1 over-budget workflow |
| 10 | Design System | [10-design-system](10-design-system/) | 🔵 In review — contrast proven by measurement in both themes; 3-screen composition proof; physical printer/device testing flagged pending for Phase 14/18 |
| 11 | API Design | [11-api](11-api/) | 🔵 In review — full contract for 7 modules + sync/realtime; 7 of 8 exit criteria met, 10× load test tracked to Phase 14/16 |
| 12 | Security Design | [12-security](12-security/) | 🔵 In review — full STRIDE across 8 boundaries, 22-table tenant-isolation checklist, cross-tenant proof extended to Realtime |
| 13 | Offline Synchronisation | [13-offline-sync](13-offline-sync/) | 🔵 In review — idempotent-replay and concurrent-composition proofs; all 10 failure scenarios resolved; all 3 standing cross-phase gaps (Finding 1, Realtime-outage, storage-full) closed |
| 14 | Testing Strategy | [14-testing](14-testing/) | 🔵 In review — full 26-rule test traceability; 3-tier CI pipeline; found and fixed a DR-025 audit-logging gap from Phase 12 |
| 15 | GitHub Project | [15-github-project](15-github-project/) | 🔵 In review — branch protection, 3-tier CI/CD workflows, full DoD-enforcing PR template; rollback rehearsal tracked to Phase 18 |
| 16 | Milestones | [16-milestones](16-milestones/) | 🔵 In review — all 5 deliverables complete; OD-06 resolved (solo, 10–20 hrs/week); V1 converts to ~10–15 months at the midpoint pace |
| 17 | Sprint Planning | [17-sprints](17-sprints/) | 🔵 In review — 2-week solo-sized cadence; M0 fully decomposed (21 person-days); M1 fully decomposed 2026-08-14 (8 items, 15.5 person-days); Sprint 01 through Sprint 18 all closed |
| 18 | Implementation | [18-implementation](18-implementation/) | 🟡 In progress — Sprints 01–15 built the full M0 walking skeleton (Identity/Auth through Bluetooth receipt printing), each closing a real gap first before writing code; Sprint 16 ran M0's own end-to-end proof for real on the founder's device — steps 1–7 (sign in, add a product, sell offline, reconnect, sync) confirmed working, no bug found, with only the physical-print step left open pending printer hardware the founder doesn't yet own; the founder then directed M1 to begin regardless (modules/README.md Rule 2's third exception), and Sprint 17/18 built the first two M1 modules (Categories and Units — `POST`/`GET /api/v1/categories` and `/units`, both live-verified, Rule 2 governing literally again). See [implementation-log.md](18-implementation/implementation-log.md) for the full per-sprint record. |

**Legend:** ⚪ Not started · 🟡 Draft · 🔵 In review · 🟢 Approved · 🔴 Blocked

---

## Cross-cutting folders

| Folder | Purpose |
| --- | --- |
| [00-governance](00-governance/) | How we work: documentation standards, Definition of Done, review rules. Applies to every phase. |
| [adr](adr/) | Architecture Decision Records. Every architecturally significant decision, with context, options considered, and consequences. Immutable once accepted. |
| [modules](modules/) | Per-module specifications. One folder per business module, authored during Phase 18 immediately before that module is implemented. |
| [reference](reference/) | External research, vendor limits, competitor analysis, regulatory notes. |
| [assets](assets/) | Diagrams, wireframes, exported images referenced by the documents. |

---

## Non-negotiable rules

1. **Design before code.** No implementation begins before its module specification is approved.
2. **One module at a time.** A module is finished — business rules, schema, API, validation, error
   handling, offline behaviour, realtime behaviour, UI, tests, documentation — before the next
   module starts.
3. **No placeholders.** No `TODO`, no stub, no "implement later" in merged code.
4. **Documentation is updated in the same pull request as the code it describes.**
5. **Every architecturally significant decision gets an ADR.** If someone will ask "why is it like
   this?" in six months, it needs an ADR.

---

## Document index

- [Glossary](GLOSSARY.md) — shared vocabulary. Ambiguous terms cause defects; this file prevents them.
- [Documentation Standards](00-governance/documentation-standards.md)
- [Definition of Done](00-governance/definition-of-done.md)
- [Ways of Working](00-governance/ways-of-working.md)
