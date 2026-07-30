# 00 — Governance

> **Status:** 🟢 Approved (foundational)
> **Version:** 1.0.0
> **Last updated:** 2026-07-28
> **Owner:** CTO

Governance is not a phase. It is the set of rules that every phase obeys. It exists before Phase 01
because without it the other seventeen phases produce documents nobody trusts.

## Contents

| Document | Purpose |
| --- | --- |
| [Documentation Standards](documentation-standards.md) | Structure, status headers, naming, versioning, and the rules that keep documents synchronised with code. |
| [Definition of Done](definition-of-done.md) | The checklist a module must satisfy before it is considered complete. Non-negotiable. |
| [Ways of Working](ways-of-working.md) | Branching, commits, pull requests, review expectations, and how decisions get made and recorded. |

## Why governance comes first

Three failure modes kill commercial software projects built by small teams:

1. **Documentation rot.** Documents describe a system that no longer exists. Everyone stops reading
   them. The knowledge lives only in one person's head. Prevented by: documentation updated in the
   same pull request as the code.
2. **Undefined done.** "Finished" features come back three times. Velocity looks high, quality is
   low, and rework consumes the schedule. Prevented by: an explicit Definition of Done.
3. **Undocumented decisions.** Six months later nobody remembers why the stock table is
   append-only, so someone "simplifies" it and corrupts the inventory. Prevented by: ADRs.

Each of these costs more to fix later than it costs to prevent now.
