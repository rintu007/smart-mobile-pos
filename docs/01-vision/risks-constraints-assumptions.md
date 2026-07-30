# Risks, Constraints & Assumptions

> **Status:** 🟢 Approved
> **Phase:** 01 — Project Vision
> **Version:** 1.0.0
> **Last updated:** 2026-07-28
> **Owner:** CTO
> **Approved by:** Founder, 2026-07-28

---

## 1. Constraints

Fixed inputs. Not up for debate; the design must work within them.

| # | Constraint | Source | Design consequence |
| --- | --- | --- | --- |
| C-01 | Android phone/tablet is the primary and sufficient platform | Founder | Every operational workflow works on a 5-inch screen. Web is optional, never required. |
| C-02 | Must operate fully offline, indefinitely | Founder | Local database is authoritative at point of sale. Sync is a first-class subsystem, not a background task. |
| C-03 | Zero technical knowledge required | Founder | Defaults over settings. No configuration screen may require a technical concept. |
| C-04 | Free and open-source services preferred; paid only where unavoidable | Founder | Drives hosting, storage and notification choices. **See R-01 — this constraint has a hard boundary.** |
| C-05 | Permissive licences only (MIT / BSD / Apache-2.0) | CTO | No GPL/AGPL dependencies — incompatible with closed-source commercial distribution. |
| C-06 | Small team, long horizon | Reality | Boring technology. Narrow release slices. Automation over process. |
| C-07 | Flutter + Next.js + PostgreSQL stack | Founder | Accepted. All three are mature, permissively licensed and well-staffed by community. |

---

## 2. Assumptions

Things we currently believe **without evidence**. Each has a validation method and a stated
consequence if it turns out false. An assumption nobody plans to test is a risk in disguise.

| # | Assumption | Validate by | If false |
| --- | --- | --- | --- |
| A-01 | Target shops have an Android device capable of running the app (Android 8+, 2 GB RAM) | Pilot device survey | Minimum spec drops; performance budget tightens significantly |
| A-02 | Owners will accept a phone camera as a barcode scanner for typical volumes | Pilot observation of scan speed and failure rate | Bluetooth scanner support moves from optional to V1-required |
| A-03 | Shops will pay a monthly subscription for software | Pilot willingness-to-pay interviews | Business model changes; possibly transaction-fee or one-off licence |
| A-04 | Offline capability is the deciding purchase factor | Pilot interviews; measured offline sale share | Our core differentiator is not a differentiator — repositioning required |
| A-05 | A 16-module V1 is genuinely usable for a full trading day | Pilot: one shop, one full week, no fallback to notebook | V1 boundary expands; timeline extends |
| A-06 | Owners will use the QR catalogue and their customers will scan it | V3 pilot | V3 deprioritised in favour of deeper core |
| A-07 | Bluetooth ESC/POS thermal printers in the target market are compatible with common command sets | Buy three cheap market-typical printers and test **before** V1 UI work | Printing becomes a per-model support burden; may need a driver abstraction layer |
| A-08 | Infrastructure cost per shop stays low enough for the intended price point | Cost model in Phase 02; measured in pilot | Pricing rises, or architecture changes to reduce per-tenant cost |
| A-09 | Free-tier infrastructure is sufficient through pilot | Monitor limits during pilot | Paid tier required earlier than planned |

---

## 3. Risks

Scored **Impact × Likelihood**, both 1–5. Priority = product. Anything ≥ 12 needs an active
mitigation owner, not a note.

### R-01 · Free-tier constraint does not survive commercial launch — **Priority 20** (I5 × L4)

**This is the most under-examined item in the founding brief, so it is listed first.**

The "only free services" constraint is correct for development and pilot. It has a hard boundary at
commercial launch, and the boundary needs to be acknowledged now so pricing (Phase 02) is built on
real numbers.

Three specific issues to verify — **each must be checked against current vendor terms during
Phase 02, not taken from memory**:

1. **Hosting licence terms.** Several platforms' free tiers are licensed for *non-commercial use
   only*. Deploying revenue-generating software on such a tier is a licence breach, and the remedy
   is typically suspension — of production, without notice. This is a legal constraint, not a
   performance one, and no amount of staying inside the resource limits fixes it.
2. **Managed-database free tiers pause on inactivity** and cap database size, storage and egress.
   A paused database means a shop cannot sync. For pilot this is survivable; for paying customers
   it is not.
3. **Public map tile servers prohibit commercial-scale use.** The OpenStreetMap Foundation's
   community tile servers are explicitly not for heavy or commercial applications. OSM *data* is
   free; OSM's *donated tile infrastructure* is not a free CDN. Delivery tracking will need
   self-hosted tiles or a provider with commercial terms.

Additionally, **payment processing is never free** — card and mobile-money providers charge per
transaction, universally. This is genuinely unavoidable and is a cost of the V3 slice.

**Mitigation**
- Treat free tiers as a *development and pilot* budget with a known expiry, not the production plan.
- Build a cost-per-tenant model in Phase 02 **before** pricing is set (metric in
  [success-metrics.md](success-metrics.md) §5).
- Keep the deployment target portable: standard PostgreSQL, containerisable Next.js, no
  vendor-proprietary compute primitives in business logic. Portability is the actual insurance —
  it converts a vendor problem into a migration, not a crisis.
- Verify current licence and limit terms in writing during Phase 02. Record as an ADR.

**Owner:** CTO · **Decision required:** [OD-02](open-decisions.md)

---

### R-02 · Offline sync corrupts stock or money — **Priority 20** (I5 × L4)

Two terminals sell the last unit offline. Both sync. Without the right model, the stock count is
wrong, and worse, *silently* wrong — nobody notices until a physical count months later, by which
time the trust is gone and the cause is unrecoverable.

This is the single hardest engineering problem in the product, and the one most likely to be
underestimated because it *appears* to work in every test on a fast connection.

**Mitigation**
- Append-only stock ledger; clients record **deltas**, never absolute quantities. Concurrent
  offline sales then compose arithmetically instead of conflicting.
- Client-generated identifiers and idempotency keys on every mutation, so retries cannot duplicate.
- Sales immutable; corrections are new linked events.
- Overselling treated as a **business** outcome (allow, record, alert) rather than a technical
  conflict to be merged. The merge has no correct answer; the business rule does.
- Per-entity-class conflict policy, decided explicitly in Phase 13 — not one global rule.
- Adversarial test suite: kill the app mid-sync, replay queues twice, clock skew, partial writes.
  This suite is a V1 deliverable, not a hardening pass.

**Owner:** CTO · **Forces ADRs on stock model and conflict resolution**

---

### R-03 · Scope defeats delivery — **Priority 20** (I5 × L4)

62 modules under a strict Definition of Done, built by a small team, is a multi-year programme with
no user feedback until the end. The realistic failure is not "we build the wrong thing" — it is
"we never finish anything."

**Mitigation:** the four-slice plan in [scope-and-release-slices.md](scope-and-release-slices.md).
Requires founder approval of the V1 boundary. **This is the decision with the largest effect on
whether the product ever ships.**

**Owner:** Founder · **Decision required:** [OD-04](open-decisions.md)

---

### R-04 · Split-brain authorisation model — **Priority 16** (I4 × L4)

If the mobile client speaks to our API for some operations and directly to the database platform
for others, we get two authorisation models, two audit trails and two offline stories. They will
disagree. When they disagree in a multi-tenant system, the failure mode is one shop seeing another
shop's data — the one failure we said was absolute.

**Mitigation:** single API surface for all writes; database-level Row Level Security as an
independent second line of defence rather than the primary one **for API-fronted access — the
direct-realtime exception this mitigation itself carves out is precisely the one boundary where RLS
is the primary and only line, per [system-context.md §4](../04-srs/system-context.md#4-trust-boundaries--the-list-phase-12-inherits)**;
direct platform access limited to read-only realtime and signed-URL file transfer. Cross-tenant
access attempts are an automated test case on every table, not a review item.

**Owner:** CTO · **Decision required:** [OD-03](open-decisions.md)

---

### R-05 · Thermal printer fragmentation — **Priority 12** (I3 × L4)

Cheap Bluetooth thermal printers vary in ESC/POS dialect, paper width, code page and pairing
behaviour. "Print receipt" is a promise made to every shop, and a printer that will not print makes
the product feel broken regardless of what else works.

**Mitigation:** buy three market-typical printers before V1 UI work (A-07); abstract printing
behind our own driver interface; ship a printer test page in settings; always offer share-as-PDF as
a fallback path so a failed printer never blocks a sale.

**Owner:** Principal Flutter Engineer

---

### R-06 · Tax and receipt legal requirements are market-specific — **Priority 12** (I4 × L3)

VAT, GST, sales tax, mandatory receipt fields, sequential invoice numbering, fiscal reporting and
retention periods differ by jurisdiction — and several jurisdictions mandate gapless invoice
sequences, which collides directly with offline operation.

**Mitigation:** the tax engine is configurable from the start (inclusive/exclusive, multi-rate,
per-product rate, rounding rule) rather than hard-coded to one market. Invoice numbering must be
designed for offline from day one: a device-scoped provisional number that is **preserved and
mapped**, never renumbered after sync, because renumbering breaks the audit trail the law is asking
for. Blocked on the launch-market decision.

**Owner:** Business Analyst · **Decision required:** [OD-01](open-decisions.md)

---

### R-07 · Serverless database connection exhaustion — **Priority 12** (I4 × L3)

Serverless functions plus a traditional connection-per-instance ORM exhausts PostgreSQL connection
limits under load. This does not appear in development; it appears on the busiest trading day.

**Mitigation:** connection pooling in transaction mode, configured and **load-tested in Phase 11**,
not discovered in production. Load test at 10× expected peak before GA.

**Owner:** DevOps Engineer

---

### R-08 · Low-end device performance — **Priority 9** (I3 × L3)

A 5,000-item catalogue, a local database, image assets and a sync engine on a 2 GB device.
Performance measured on a development machine is not evidence.

**Mitigation:** a reference low-end device named in Phase 14; performance budgets in
[success-metrics.md](success-metrics.md) §3 enforced in CI where measurable; paginated and indexed
local queries from the first implementation rather than as an optimisation pass.

**Owner:** Principal Flutter Engineer

---

### R-09 · Device loss with unsynced sales — **Priority 12** (I4 × L3)

A phone is lost, stolen or wiped while holding a day of unsynced sales. Those sales exist nowhere
else. This violates "the sale is sacred" and no server-side measure can recover them.

**Mitigation:** sync opportunistically and aggressively whenever any connectivity exists, rather
than on a timer; surface unsynced count prominently in the interface; warn on day-close if the
queue is non-empty; consider local encrypted export to the device's shared storage as a last
resort. Full mitigation is impossible — this risk is **reduced, never eliminated**, and that
limitation is disclosed to shop owners rather than hidden.

**Owner:** CTO

---

### R-10 · Single-maintainer dependency abandonment — **Priority 6** (I3 × L2)

Hardware-adjacent Flutter packages (Bluetooth printing, scanning) are frequently maintained by one
person.

**Mitigation:** dependency policy in [ways-of-working.md](../00-governance/ways-of-working.md) §7;
wrap volatile dependencies behind our own interfaces so replacement is local; no third-party type
appears in domain code.

**Owner:** Principal Flutter Engineer

---

## 4. Risk summary

| ID | Risk | Priority | Owner | Blocked on decision |
| --- | --- | --- | --- | --- |
| R-01 | Free-tier constraint vs commercial launch | 20 | CTO | OD-02 |
| R-02 | Offline sync corrupts stock or money | 20 | CTO | — |
| R-03 | Scope defeats delivery | 20 | Founder | OD-04 |
| R-04 | Split-brain authorisation | 16 | CTO | OD-03 |
| R-05 | Printer fragmentation | 12 | Flutter | — |
| R-06 | Market-specific tax and receipt law | 12 | BA | OD-01 |
| R-07 | Connection exhaustion | 12 | DevOps | — |
| R-08 | Low-end device performance | 9 | Flutter | — |
| R-09 | Device loss with unsynced sales | 12 | CTO | — |
| R-10 | Dependency abandonment | 6 | Flutter | — |

---

## 5. Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-28 | Initial draft. |
| 1.0.0 | 2026-07-28 | Approved. R-01 mitigated via [ADR-0002](../adr/ADR-0002-hosting-posture-for-commercial-launch.md). R-04 mitigated via [ADR-0001](../adr/ADR-0001-hybrid-api-and-direct-realtime-access.md). |
