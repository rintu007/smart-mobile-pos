# Definition of Done

> **Status:** 🟢 Approved (foundational)
> **Version:** 1.0.0
> **Last updated:** 2026-07-28
> **Owner:** CTO / QA Lead

"Done" is not "the happy path works on my phone." A module is done when it survives contact with
a real shop that has bad WiFi, a cracked screen, an untrained cashier and no patience.

---

## A module is DONE when every box is ticked

### Specification
- [ ] Module specification exists in `modules/<module>/` with all eleven sections authored.
- [ ] Specification is 🟢 Approved.
- [ ] Every business rule is written as a testable statement.
- [ ] Traceability table links back to Business and Functional Requirements.

### Data
- [ ] Schema is documented in `07-database/` with relationships and indexes.
- [ ] Prisma migration is written, reviewed and applied to the development database.
- [ ] Migration is **reversible**, or its irreversibility is explicitly documented and justified.
- [ ] Row Level Security policies exist for every new table and are tested from the perspective of
      a wrong-tenant user.
- [ ] Indexes exist for every query the module actually runs. Verified with `EXPLAIN ANALYZE`, not
      assumed.

### API
- [ ] Endpoints match the approved contract in `11-api/` exactly.
- [ ] Every input is validated with a Zod schema at the boundary. No exceptions.
- [ ] Every mutating endpoint is **idempotent** or explicitly documented as not-safe-to-retry.
- [ ] Authentication and authorisation enforced server-side. Client-side permission checks are
      user experience only and are never trusted.
- [ ] Error responses use the standard error envelope with a stable machine-readable code.
- [ ] Rate limiting applied where abuse is possible.

### Mobile
- [ ] Works offline for every operation the specification says works offline.
- [ ] Queued operations survive app kill, device reboot and low-storage conditions.
- [ ] Sync is idempotent — replaying the queue twice must not double-write.
- [ ] Every screen handles loading, empty, error, offline and permission-denied states.
- [ ] Works on a 5-inch phone and a 10-inch tablet.
- [ ] Works in light and dark mode.
- [ ] Minimum touch target 48 dp; screen reader labels on all interactive elements.
- [ ] No jank: verified on a low-end device, not only on the development machine.

### Security
- [ ] Threat-modelled against the module's own attack surface.
- [ ] No secret, token or key is written to logs, analytics or crash reports.
- [ ] Sensitive data at rest uses secure storage, not shared preferences.
- [ ] Audit log entries written for every action that changes money, stock or permissions.

### Tests
- [ ] Unit tests for all business rules, including the failure branches.
- [ ] Widget tests for every screen's state matrix.
- [ ] Integration test for the primary end-to-end workflow.
- [ ] **At least one test proves the offline → online sync path**, including a conflict.
- [ ] Tests pass in CI on a clean checkout.

### Documentation
- [ ] Module specification updated to match what was actually built.
- [ ] API documentation updated.
- [ ] Any decision made during implementation is captured as an ADR.
- [ ] Glossary updated with any new domain term.

### Product
- [ ] Owner-facing workflow completed end-to-end by someone who did not write the code.
- [ ] Tap count for the primary workflow measured and recorded against its target.

---

## A phase is DONE when

- [ ] All deliverables listed in the phase charter exist and are 🟢 Approved.
- [ ] All exit criteria in the phase charter are satisfied.
- [ ] Open decisions raised in the phase are either resolved or explicitly deferred with an owner
      and a deadline.
- [ ] The status table in [docs/README.md](../README.md) is updated.

---

## What "done" explicitly does **not** mean

- It does not mean "it works on my machine."
- It does not mean "tests pass" — tests passing is one box of many.
- It does not mean "we will clean it up in the next sprint." That sprint never arrives; this is how
  products accumulate the debt that eventually stops them shipping.
