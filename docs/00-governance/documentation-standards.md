# Documentation Standards

> **Status:** 🟢 Approved (foundational)
> **Version:** 1.0.0
> **Last updated:** 2026-07-28
> **Owner:** CTO

---

## 1. Every document carries a status header

Every Markdown file in `docs/` begins with this block, immediately after the `# Title`:

```markdown
> **Status:** 🔵 In review
> **Phase:** 01 — Project Vision
> **Version:** 0.1.0
> **Last updated:** 2026-07-28
> **Owner:** CTO
> **Approved by:** _pending_
```

**Status values**

| Symbol | Status | Meaning |
| --- | --- | --- |
| ⚪ | Not started | The file exists as a charter only. No content authored. |
| 🟡 | Draft | Content authored, not yet reviewed. **Do not build against it.** |
| 🔵 | In review | Submitted for approval. Comments open. |
| 🟢 | Approved | Binding. Code may be built against it. Changes require a version bump. |
| 🔴 | Blocked | Cannot progress. The blocker must be named in the document. |
| ⚫ | Superseded | Replaced. Must link to the replacement. Never deleted. |

A document is **never deleted**. It is marked ⚫ Superseded and linked forward. Deleting history
destroys the ability to answer "why did we change this?".

---

## 2. Versioning

Documents use semantic versioning independent of the application version.

| Change | Bump |
| --- | --- |
| Typo, formatting, clarification that changes no meaning | patch — `1.0.0 → 1.0.1` |
| New content added, nothing invalidated | minor — `1.0.0 → 1.1.0` |
| Existing approved statement changed or removed | major — `1.0.0 → 2.0.0` |

**A major bump on an 🟢 Approved document requires re-approval** and an entry in the document's
Change Log section. Anything built against the old major version must be re-verified.

---

## 3. Naming

| Item | Convention | Example |
| --- | --- | --- |
| Folders | `NN-kebab-case` for phases, `kebab-case` otherwise | `07-database`, `modules` |
| Files | `kebab-case.md` | `success-metrics.md` |
| Phase index | Always `README.md` | `01-vision/README.md` |
| ADRs | `ADR-NNNN-kebab-title.md` | `ADR-0007-append-only-stock-ledger.md` |
| Requirement IDs | `BR-NNN`, `FR-NNN`, `NFR-NNN`, `US-NNN`, `RR-NNN` (regulatory), `DR-NNN` (domain/business rule) | `FR-042` |

**Requirement IDs are permanent and never reused.** A withdrawn requirement is marked withdrawn,
not deleted, and its number is retired. Reusing an ID makes traceability lie.

---

## 4. Traceability

Every requirement must be traceable forward and backward:

```
Business Requirement (BR)
  → Functional Requirement (FR)
    → API endpoint / Database table
      → Test case
        → Implemented module
```

Each phase document maintains a traceability table. An FR with no BR is scope creep. A BR with no
FR is an unimplemented promise. Both are defects and both are caught by reviewing these tables.

---

## 5. Writing rules

- **Write decisions, not options.** Documents state what we will do. Options and rejected
  alternatives belong in the ADR, not in the specification.
- **Every number has a source.** "Must load in under 300 ms" needs a rationale. "Fast" is not a
  requirement — it is not testable, therefore it is not a requirement.
- **Prefer tables to prose** for anything enumerable. Prose hides gaps; tables expose them.
- **No marketing language in technical documents.** "Blazing fast, world-class architecture" tells
  a future engineer nothing.
- **British English spelling**, consistent with the product vocabulary (`Favourite`, `Synchronise`,
  `Colour`). This matters because it leaks into identifiers and user-facing strings.
- **Diagrams as Mermaid**, inline in the Markdown. Mermaid is text, so it diffs, reviews and
  version-controls properly. Binary diagram files do none of those things and rot immediately.

---

## 6. Synchronisation with code

This is the rule that keeps the documentation alive:

> **A pull request that changes behaviour and does not change documentation is rejected.**

Specifically:

| Code change | Mandatory documentation change |
| --- | --- |
| New or changed API endpoint | `11-api/` endpoint specification |
| New or changed database table or column | `07-database/` schema documentation + migration note |
| New business rule | The owning module specification in `modules/` |
| New or changed screen | `09-navigation/` route map + `10-design-system/` if new patterns |
| Architecturally significant choice | New ADR |
| New environment variable or secret | `12-security/` configuration inventory |

---

## 7. Module specification template

Every module in `modules/` documents all eleven sections. **A missing section blocks
implementation** — it means a decision has not been made, and undecided decisions become bugs.

1. Purpose and business context
2. Business rules
3. Database tables and relationships
4. API contract (request, response, status codes, error codes)
5. Validation rules (client and server)
6. Error handling and user-facing messages
7. Offline behaviour (what works offline, what queues, how it merges)
8. Realtime behaviour (what pushes, to whom, and what happens if the push is missed)
9. UI specification (screens, states, empty/loading/error, tablet and phone)
10. Test plan (unit, widget, integration, end-to-end)
11. Traceability (which BR/FR this satisfies)

---

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 1.0.0 | 2026-07-28 | Initial standards established. |
