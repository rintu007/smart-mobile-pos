# Pull Request Template

> **Status:** 🔵 In review
> **Phase:** 15 — GitHub Project
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** CTO
> **Approved by:** _pending_

The checklist from the Definition of Done, embedded directly in `.github/pull_request_template.md`
— per this phase's exit criterion, this **mechanically enforces** the checklist (every PR
description starts with these exact boxes, unchecked, per
[definition-of-done.md](../00-governance/definition-of-done.md)) rather than trusting a contributor
to remember to consult a separate document.

---

## Template content

```markdown
## What this PR does

<!-- One or two sentences. Link the issue(s) it closes. -->

## Definition of Done

Not every PR closes every box below — check only what this PR actually completes. **A PR claiming
to finish a module must have every box checked**, per definition-of-done.md; a partial PR toward a
module leaves the rest visibly unchecked, not silently omitted.

### Specification
- [ ] Module specification exists in `modules/<module>/` with all eleven sections authored.
- [ ] Specification is 🟢 Approved.
- [ ] Every business rule is written as a testable statement.
- [ ] Traceability table links back to Business and Functional Requirements.

### Data
- [ ] Schema is documented in `07-database/` with relationships and indexes.
- [ ] Prisma migration is written, reviewed and applied to the development database.
- [ ] Migration is reversible, or its irreversibility is explicitly documented and justified.
- [ ] Row Level Security policies exist for every new table and are tested from the perspective of a wrong-tenant user.
- [ ] Indexes exist for every query the module actually runs. Verified with `EXPLAIN ANALYZE`.

### API
- [ ] Endpoints match the approved contract in `11-api/` exactly.
- [ ] Every input is validated with a Zod schema at the boundary.
- [ ] Every mutating endpoint is idempotent, or explicitly documented as not-safe-to-retry.
- [ ] Authentication and authorisation enforced server-side.
- [ ] Error responses use the standard error envelope with a stable machine-readable code.
- [ ] Rate limiting applied where abuse is possible.

### Mobile
- [ ] Works offline for every operation the specification says works offline.
- [ ] Queued operations survive app kill, device reboot and low-storage conditions.
- [ ] Sync is idempotent — replaying the queue twice does not double-write.
- [ ] Every screen handles loading, empty, error, offline and permission-denied states.
- [ ] Works on a 5-inch phone and a 10-inch tablet, in light and dark mode.
- [ ] Minimum touch target 48 dp; screen reader labels on all interactive elements.
- [ ] No jank: verified on a low-end device.

### Security
- [ ] Threat-modelled against this change's attack surface.
- [ ] No secret, token or key is written to logs, analytics or crash reports.
- [ ] Sensitive data at rest uses secure storage, not shared preferences.
- [ ] Audit log entries written for every action that changes money, stock or permissions.

### Tests
- [ ] Unit tests for all business rules, including the failure branches.
- [ ] Widget tests for every screen's state matrix.
- [ ] Integration test for the primary end-to-end workflow.
- [ ] At least one test proves the offline → online sync path, including a conflict.
- [ ] Tests pass in CI on a clean checkout.

### Documentation
- [ ] Module specification updated to match what was actually built.
- [ ] API documentation updated.
- [ ] Any decision made during implementation is captured as an ADR.
- [ ] Glossary updated with any new domain term.

### Product
- [ ] Owner-facing workflow completed end-to-end by someone who did not write the code.
- [ ] Tap count for the primary workflow measured and recorded against its target.

## Solo-review compensating control

If no second reviewer is available (see repository-setup.md §3), the author confirms:
- [ ] I have re-read every checked box above as if reviewing someone else's work, not my own.
```

## Why every box ships in every PR, not a per-category subset

A template that tried to guess which categories apply and show only those would need logic a static
Markdown template file cannot express, and would risk hiding a box that *did* apply but wasn't
anticipated. Showing all of them, unchecked by default, and trusting the contributor to leave
genuinely inapplicable ones unchecked with a brief note, is simpler and matches how
[definition-of-done.md](../00-governance/definition-of-done.md) itself already presents the full
list without conditional logic.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Full Definition-of-Done checklist embedded verbatim as the PR template; solo-review compensating control added as an explicit, checked step. |
