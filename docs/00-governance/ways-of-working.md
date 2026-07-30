# Ways of Working

> **Status:** 🟢 Approved (foundational)
> **Version:** 1.0.0
> **Last updated:** 2026-07-28
> **Owner:** CTO

---

## 1. The loop

```
Design → Review → Approve → Implement → Test → Document → Merge → Next module
```

There is no shortcut around any arrow. The most expensive defects in a POS system are design
defects — a wrong stock model or a wrong invoice-numbering rule corrupts data that cannot be
recovered, because the correct value was never recorded anywhere.

---

## 2. Repository strategy

**Decision: monorepo.**

```
smart-pos/
├── docs/          # Single source of truth
├── apps/
│   ├── mobile/    # Flutter — Android first
│   └── web/       # Next.js — API, admin, QR storefront
└── packages/
    └── shared/    # Cross-platform contracts (API types, error codes, enums)
```

**Rationale.** The API contract and the mobile client change together. In split repositories they
drift, and the drift is discovered by a cashier at a till, not by CI. A monorepo makes a
contract-breaking change impossible to merge without touching both consumers in the same pull
request. The cost is a slightly more complex CI configuration — a good trade.

---

## 3. Branching

| Branch | Purpose | Protection |
| --- | --- | --- |
| `main` | Always releasable. Every commit is a candidate build. | Protected. No direct pushes. |
| `feat/<module>-<short>` | One module or one slice of a module. | — |
| `fix/<short>` | Defect repair. | — |
| `docs/<phase>` | Documentation-only changes for a phase. | — |

No long-lived `develop` branch. Long-lived branches accumulate merge risk that has to be paid all
at once, usually at the worst moment.

---

## 4. Commits

Conventional Commits, because they let the changelog and version bumps be generated rather than
maintained by hand:

```
feat(pos): add split payment across cash and wallet
fix(sync): prevent duplicate sale on queue replay after app kill
docs(07-database): document stock ledger indexes
refactor(inventory): extract stock movement writer into service layer
test(returns): cover partial return exceeding original quantity
```

Scope is the module name. A commit touching three modules is a sign the work was not sliced along
module boundaries.

---

## 5. Pull requests

A pull request must state:

1. **What** changed.
2. **Why** — linked to a Functional Requirement or a defect.
3. **How it was verified** — which tests, and what was checked manually on a device.
4. **What documentation changed**, and if none, why none was needed.

**Rejection criteria — automatic, not negotiable:**

- Contains `TODO`, `FIXME`, commented-out code, or a stubbed function.
- Behaviour changed, documentation did not.
- No tests for new business logic.
- Introduces a dependency without justification recorded in the pull request.
- Adds a database column without a migration.
- Adds a table without Row Level Security policies.

---

## 6. Decisions

| Decision type | Recorded where |
| --- | --- |
| Architecturally significant — hard or expensive to reverse, affects multiple modules, or constrains future choices | ADR in `docs/adr/` |
| Product scope | Phase 01 / 02 documents |
| Implementation detail — local, cheaply reversible | Code comment or pull request description |

**Test for "architecturally significant":** if reversing it in six months would require a data
migration, an API version bump, or rewriting more than one module — it needs an ADR.

An ADR is **immutable once accepted**. It is never edited to reflect a new decision. A new decision
gets a new ADR that supersedes the old one, and the old one is marked ⚫ Superseded with a forward
link. The history of what we believed, and when, is itself valuable.

---

## 7. Dependency policy

Before any package is added:

1. **Is it needed?** Ten lines of our own code beats a dependency with a transitive tree.
2. **Is it maintained?** Last release within twelve months; open issues being answered.
3. **Is it licensed permissively?** MIT, BSD, Apache-2.0. **No GPL or AGPL** — this is commercial,
   closed-source software and copyleft licences are incompatible with that.
4. **What is the exit cost?** If it is abandoned, how hard is replacement? Wrap volatile
   dependencies behind our own interface; do not let a third-party type appear in domain code.
5. **Is it free forever, or free until it is not?** Note anything that could introduce a bill.

The justification is recorded in the pull request. Every dependency is a permanent liability.

---

## 8. Definition of "challenge"

Any team member — human or AI — is expected to challenge a decision they believe is wrong, once,
clearly, with a concrete alternative and its trade-offs. After the decision-maker has heard the
challenge and reaffirmed the decision, it is executed fully and in good faith. Re-litigating
settled decisions is how projects stall.
