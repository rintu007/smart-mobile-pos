# Phase 05 — User Personas

> **Status:** 🟡 Draft — **hard-blocked on real validation, see below**
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Product Manager / UI-UX Lead

## Charter

| | |
| --- | --- |
| **Objective** | Define the humans who use this product concretely enough that design arguments can be settled by asking "would this work for them?" rather than by opinion. |
| **Inputs** | Phase 02 market analysis (🔵 In review); no pilot shop interviews have happened yet. |

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`personas.md`](personas.md) | 7 personas — Owner, Manager, Cashier, Inventory Staff, Delivery Staff, Accountant, End Customer | 🟡 Draft, research-grounded, unvalidated |
| [`permission-matrix.md`](permission-matrix.md) | 16 capabilities × 3 V1 roles, 48 cells, all resolved; 8 rows DR-derived, 8 rows flagged as judgment calls | 🔵 In review |
| [`device-and-context.md`](device-and-context.md) | Devices, connectivity, lighting, noise, one-handed use, queue pressure — consolidated for Phase 09/10 | 🔵 In review |
| [`accessibility-profiles.md`](accessibility-profiles.md) | Literacy, language, age-related vision, colour vision deficiency | 🔵 In review |

## Exit criteria

- [x] Each persona states goals, frustrations, technical confidence, device, and the context of use — all 7.
- [x] Each persona names the **one workflow** they perform most, with a tap-count budget (or an explicit, justified exception — see Accountant, End Customer in V1).
- [x] The permission matrix covers every V1 capability with no undefined cells — 48/48 cells resolved.
- [ ] **At least three personas are validated against real people, not invented. Not met, and cannot be met through further research.**

## This phase cannot be marked 🟢 Approved without real conversations

Unlike the GST-practitioner review or the OD-01 market confirmation blocking Phases 02–04, this
gap is not a research task — it requires someone to actually talk to a real Owner, Manager, and
Cashier and check whether [personas.md](personas.md) matches reality. **What that would concretely
look like:** 3–5 short interviews each for the Owner, Manager, and Cashier personas (the three
driving current design decisions), checking goals, frustrations, device, and context against what's
written, and correcting whatever doesn't hold up. This overlaps with — and doesn't have to wait for
— the pilot-shop recruitment already planned in [16-milestones](../16-milestones/README.md).

**Proceeding to Phase 06 anyway**, because workflow design needs *a* persona baseline to build
against, and research-grounded is a legitimate starting point — but every workflow built on these
personas inherits this same unvalidated status until real conversations happen. The earlier that
happens, the less of Phases 06–10 needs rework.

## Rules

- Personas are grounded in the market analysis, not imagined. An invented persona validates
  whatever the designer already wanted to build.
- The Cashier persona has veto power over POS design. They are under queue pressure, possibly
  untrained, possibly temporary — the harshest usability test the product faces.
