# Project Board

> **Status:** 🔵 In review
> **Phase:** 15 — GitHub Project
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** CTO
> **Approved by:** _pending_

Columns, item types, fields, and how work flows across them — using **GitHub Projects (the
built-in, free "Projects" board)**, not a third-party tool, consistent with this project's
free/open-source-first constraint and the fact it's already co-located with the issues it tracks.

---

## 1. Columns (status field)

```
Backlog → Ready → In Progress → In Review → Blocked → Done
```

| Column | Meaning | Exit condition |
| --- | --- | --- |
| Backlog | Raised, not yet scoped for a specific sprint | Moved to Ready once a Phase 17 sprint plan includes it |
| Ready | Scoped, has an owner, unblocked | A PR is opened referencing this item |
| In Progress | Actively being worked | PR opened and passing CI |
| In Review | PR open, awaiting the review discipline in [repository-setup.md §2–3](repository-setup.md#2-branch-protection-on-main) | Approved and merged |
| Blocked | Explicitly stalled — always carries a linked reason (a dependency, an open decision from [open-decisions.md](../01-vision/open-decisions.md), a founder-only action per [device-matrix.md §3](../14-testing/device-matrix.md#3-this-is-a-founder-action-not-an-engineering-one--stated-plainly)) | The blocking condition is resolved |
| Done | Merged **and** meets the relevant Definition of Done bar ([definition-of-done.md](../00-governance/definition-of-done.md)) | Terminal |

**Blocked is a real column, not a euphemism for Backlog** — per this phase's "if a rule matters,
automate it" ethos, an item that silently sits in Backlog because it's actually blocked hides the
reason it isn't moving; a Blocked item is required to carry a linked cause so the board itself
answers "why isn't this moving" without asking anyone.

## 2. Item types

| Type | Used for |
| --- | --- |
| Module | One per business module ([modules/](../modules/README.md)), tracked from specification through all seven Definition-of-Done categories |
| Feature | A scoped piece of work smaller than a full module (e.g. one endpoint, one screen) |
| Defect | A found, reproducible bug — per this phase's rule (inherited from [test-strategy.md](../14-testing/test-strategy.md)'s spirit), every Defect item is required to link the regression test that now covers it before it can move to Done |
| ADR Proposal | A candidate architecturally-significant decision, per [adr/README.md](../adr/README.md)'s register — moves to Done only once accepted and numbered |
| Security Finding | Per [Phase 12](../12-security/README.md)'s "security findings block release" rule — this item type is the one that can block a Module or Feature item from reaching Done regardless of that item's own progress |

## 3. Fields

| Field | Values | Purpose |
| --- | --- | --- |
| Module | One of the 16 V1 modules ([scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)) | Groups work by the module-at-a-time discipline this entire project runs on |
| Phase | 01–18 | Which documentation phase this item's authority traces back to — mainly relevant during the documentation build itself; less used once Phase 18 implementation is the steady state |
| Priority | P0 (blocks release) / P1 / P2 | Drives Backlog ordering, not a substitute for the Blocked column |
| Risk | Tied to [risks-constraints-assumptions.md](../01-vision/risks-constraints-assumptions.md)'s R-NNN register, where applicable | Surfaces which in-flight work touches an already-known high-risk area (e.g. anything R-02/R-07-tagged gets extra review attention) |
| Release | V1 / V2 / V3 / V4 | Matches [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)'s slices |

## 4. Automation

GitHub Projects' built-in workflows (free, no custom scripting needed) move an item: Backlog→Ready
when a milestone is assigned (Phase 16/17's job); In Progress automatically when a linked PR opens;
In Review automatically when that PR is marked ready and passing CI; Done automatically on merge —
**except** a Module item, which requires a manual move to Done, since merging code is not the same
claim as satisfying all seven Definition-of-Done categories
([definition-of-done.md](../00-governance/definition-of-done.md)) and that distinction should never
be silently automated away.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | 6-column board (Blocked as a first-class column, not a Backlog euphemism); 5 item types; 5 tracked fields; automation rules with Module items deliberately excluded from auto-Done. |
