# Offline Workflows

> **Status:** 🔵 In review
> **Phase:** 06 — Business Workflows
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** CTO
> **Approved by:** _pending_

Every V1 workflow, re-traced with no connectivity. Per this phase's rule, "requires connectivity"
is an acceptable answer for a step, but only when written and justified — most steps below need no
justification because they were designed offline-first from Phase 01 onward; this document's real
value is the **three genuine divergences** it surfaces, each flagged forward to
[13-offline-sync](../13-offline-sync/README.md) as a design input, not resolved here.

---

## Consolidated trace

| Workflow | Fully offline? | Divergence when offline |
| --- | --- | --- |
| WF-001 Shop onboarding | **No** — account creation/verification requires connectivity | Every other onboarding step is offline. This is the one deliberate, accepted exception in the entire product — [FR-001](../03-functional-requirements/functional-requirements.md). |
| WF-002 Cash sale | Yes | None. |
| WF-003 Discount sale | Yes, with a caveat | An above-threshold discount's Manager approval can be granted offline against a locally cached role, but is **provisional** until sync re-confirms the approver actually held that role — see Finding 1 below. |
| WF-004 Split payment | Yes | None — V1 has no live payment network to depend on regardless of connectivity. |
| WF-005 Hold/resume | Yes | None — purely local persistence. |
| WF-006 Cancel | Yes | None — nothing is committed to reverse. |
| WF-007 Open trading day | Yes | See Finding 2 — shared-device consistency, not a connectivity gap per se. |
| WF-008 Close trading day | Yes | See Finding 2. |
| WF-009 Opening stock | Yes | None. |
| WF-010 Stock adjustment | Yes | None. |
| WF-011 Stock count | Yes | None — the correction step is WF-010. |
| WF-012 Process a return | Yes, with a caveat | Locating the original sale depends on it having already synced to *this* device — see Finding 3. |
| WF-013 Approve high-value return | Yes, with a caveat | Same provisional-approval pattern as WF-003 — see Finding 1. |

---

## Finding 1 — Offline approvals are provisional until sync, and that needs a defined UX

WF-003 and WF-013 both allow a Manager to approve an above-threshold discount or return while
offline, checked against that device's locally cached role and threshold
([DR-017](../03-functional-requirements/business-rules.md)). But the *authoritative* check happens
server-side at sync ([DR-018](../03-functional-requirements/business-rules.md)) — if the approving
Manager's role was revoked between the offline approval and the sync (e.g. by an Owner, from
another device), the approval is rejected in full at that point.

**This is correct and intentional as a security property** — a revoked Manager cannot retroactively
approve anything once the revocation is known server-side. But it means a sale or return can be
completed at the till, receipt printed, customer gone — and then be rejected hours later at sync.
**Phase 13 must design what happens next**: this isn't a data question, it's a business-process
question (does the shop re-bill the customer? is it written off? does it just generate an alert for
the Owner to review?). Not resolved here — flagged as a required input to
[13-offline-sync/failure-scenarios.md](../13-offline-sync/README.md).

## Finding 2 — Trading Day is a shared, store-level concept, and multi-device shops need a rule

Retracing WF-007/WF-008 surfaced a question this phase isn't equipped to answer but must not let
disappear: **if a shop has more than one till/device, is there one shared Trading Day per store, or
one per device?** A single physical cash drawer suggests one shared day-state; but two offline
devices for the same store could each independently believe they're opening (or closing) "the"
day, with no way to detect the conflict until both sync.

This is not a V1-blocking question if V1 shops are overwhelmingly single-device (plausible per
[personas.md](../05-personas/personas.md), but not confirmed against real shops — another item for
the Phase 05 validation gap to eventually settle). **Flagged forward to
[13-offline-sync/conflict-resolution.md](../13-offline-sync/README.md)** as a required
entity-classification decision: is Trading Day a "client-editable" entity needing an explicit
conflict policy, or should V1 sidestep the question entirely by scoping a trading day to a device,
not a store, until multi-till shops are explicitly supported?

## Finding 3 — Return lookup is bounded by what has synced to this device

WF-012 depends on the original sale being visible in this device's local cache. In a shop with
multiple devices, a customer could reasonably return an item purchased on a till that isn't the one
they're standing in front of, before that sale has synced across. This was already noted as a
limitation in [returns-workflows.md](returns-workflows.md); recorded here as well because it's
precisely the kind of offline-visibility gap this document exists to surface. **Not a correctness
bug** — once synced, the data is accurate — but a real UX gap: the Cashier has no way to tell
whether "sale not found" means "never happened" or "hasn't synced here yet." Flagged forward to
[13-offline-sync/sync-ui.md](../13-offline-sync/README.md): the sync-state indicator
([BR-053](../02-business-requirements/business-requirements.md)) should make this distinction
visible, not just show a generic "not found."

---

## What this document deliberately does not do

It does not design the sync engine's resolution to any of the three findings above — that's
[13-offline-sync](../13-offline-sync/README.md)'s job, several phases away. Its job is only to make
sure these three questions are asked now, while retracing real workflows, rather than discovered
during Phase 13 itself with no workflow context attached to them.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial offline retrace of all 13 V1 workflows; 3 findings flagged forward to Phase 13. |
