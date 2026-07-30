# Open Decisions

> **Status:** 🟡 Draft — 5 of 6 decided, 1 provisional
> **Phase:** 01 — Project Vision
> **Version:** 0.3.0
> **Last updated:** 2026-07-31
> **Owner:** CTO (raising) / Founder (deciding)

---

**Founder instruction (2026-07-28): "take decision on your recommended way."** Where I gave a
concrete recommendation, it is now decided — see the resolution box under each item and the
[decision log](#decision-log). One item could not be resolved this way, and one required directly
asking rather than recommending:

- **OD-01 (launch market)** — I never recommended a *specific* market, only an approach ("pick
  one"). I have no basis to name a jurisdiction, and guessing wrong misdirects the entire tax/legal
  content of Phase 02. I am proceeding under a clearly labelled **provisional assumption** so work
  is not blocked, not a silent decision — see its resolution box. **Still the only open item.**
- **OD-06 (capacity)** — this was a fact about the founder, not a design choice, so I could not
  recommend a number and did not guess one. When Phase 16 actually reached this gate (2026-07-31), I
  asked directly rather than proceeding on an assumption — answered: solo, 10–20 hrs/week. Resolved.

---

## OD-01 · What is the launch market? — **Blocks Phase 02**

**Why this cannot wait.** More of the product depends on this than on any other single fact:

| Depends on launch market | How |
| --- | --- |
| Tax engine | VAT vs GST vs sales tax; inclusive vs exclusive pricing; rounding rules |
| Receipt content | Mandatory fields, tax registration display, language |
| Invoice numbering | Some jurisdictions mandate gapless sequences — this directly collides with offline operation (R-06) |
| Payment methods | Mobile money vs UPI vs cards vs cash-dominant |
| Currency and formatting | Minor units, separators, symbol placement |
| Language and script | Affects font selection, text layout, receipt printing, and the RTL question |
| Price point | Purchasing power differs by an order of magnitude across candidate markets |
| Data residency | Some jurisdictions restrict where business data may be stored |

**What I need from you:** the primary launch market, and whether a second market follows within
twelve months. If a second market is coming, the tax and localisation engines must be built
general from the start — which is more work now and vastly less later.

**My recommendation:** name **one** launch market. Build the tax and currency engines as
configurable from day one regardless, because that generality is cheap now and near-impossible to
retrofit — but design the *workflows* for one market. A product that is mediocre in five markets
loses to a product that is excellent in one.

> ### 🟡 Resolution — Provisional, not decided
> I have no reliable signal for the actual launch market — this is factual information about your
> business, not something I can responsibly infer, and getting it wrong steers all of Phase 02's
> tax, receipt-law and payment-method content in the wrong direction.
>
> **To avoid blocking, Phase 02 will proceed under a working assumption of India (GST) as the
> launch market** — chosen only because it is the single most common launch market for products of
> exactly this shape (Android-first, offline-first, small-retail-first, the specific vertical mix
> in the brief) and it keeps the regulatory research concrete instead of generic. **This is not a
> decision — it is a placeholder that must be confirmed or corrected before any Phase 02 content is
> treated as final.** Nothing in Phases 07–18 is downstream-committed to it yet; the tax engine is
> already required to be configurable (see [ADR backlog](../adr/README.md)), so correcting the
> market later is a Phase 02 rewrite, not an architecture change.
>
> **Say the word and I'll swap it for the real market** — the earlier that happens, the less of
> Phase 02 needs redoing.

---

## OD-02 · Hosting posture for commercial launch — **Blocks Phase 12; decide by Phase 02**

**Context.** Your constraint is "free services only." That works for development and pilot. It has
a hard boundary at the point real customers pay you — see R-01, particularly the licence question,
which is not solved by staying inside resource limits.

**Options**

| Option | Cost posture | Trade-off |
| --- | --- | --- |
| **A — Free tiers throughout, accept the boundary** | Free until launch, then forced migration under time pressure | Cheapest now, most expensive at the worst possible moment |
| **B — Free for development, budget a modest paid production tier** | Small fixed monthly cost from launch | Predictable; standard practice; removes a launch-day crisis |
| **C — Self-host on a single small VPS** | Very low fixed cost, full control | You own backups, patching, uptime and scaling. Real operational burden for a small team. |

**My recommendation: B, with the architecture built so C stays available.** Keep everything
portable — standard PostgreSQL, no proprietary compute primitives in business logic, containerisable
API. Portability is the actual insurance: it converts any vendor problem into a scheduled migration
rather than an emergency. The genuinely unavoidable costs are hosting at commercial terms, a domain
name, the Play Store registration, and payment-processing fees in V3. Everything else stays free
and open-source, as you asked.

**What I need from you:** a rough monthly infrastructure budget ceiling for launch. Even "under $50"
is enough to design against.

> ### 🟢 Resolution — Decided: Option B
> Free tiers through development and pilot; a modest budgeted paid production tier from commercial
> launch, with the architecture kept portable so self-hosting stays available as an escape hatch.
> Recorded in **[ADR-0002](../adr/ADR-0002-hosting-posture-for-commercial-launch.md)**.
> The specific budget ceiling is still unknown and remains a genuinely open input — it doesn't block
> any phase before Phase 02's cost model, so it's tracked there rather than here.

---

## OD-03 · Does the mobile client talk to the database platform directly? — **Decide by Phase 07**

**Context.** The chosen stack allows two paths, and using both creates the split-brain problem in
R-04: two authorisation models, two audit trails, two offline stories.

**Options**

| Option | Description |
| --- | --- |
| **A — API-only** | All reads and writes go through our Next.js API. Database platform used only for authentication and file storage. |
| **B — Direct platform access** | Client uses the platform SDK directly for CRUD; Row Level Security is the only authorisation. Fast to build, but business rules end up in the client, and a rule that lives in the client is a rule an attacker controls. |
| **C — Hybrid, with strict boundaries** | All **writes** and all business logic through our API. **Realtime read subscriptions** direct, secured by Row Level Security. File upload/download direct via short-lived signed URLs issued by our API. |

**My recommendation: C, with the boundary written down and enforced in review.** Business rules —
stock movements, invoice numbering, tax calculation, returns eligibility — cannot live in a mobile
client that a determined user can decompile and modify. But routing realtime read streams through
our API would mean reimplementing a solved problem badly. Row Level Security stays enabled on every
table as an independent second line of defence behind the API for every write and API-fronted read
— **with one specific exception, identified precisely once system-context.md's trust-boundary
analysis reached it in Phase 04: for the Realtime read subscriptions this very option describes, no
API layer sits in front of them at all, so RLS is that boundary's sole gate, not a second line.**
This isn't a contradiction of the choice made here, just a detail this document didn't yet have the
vocabulary to state precisely — see [system-context.md §4](../04-srs/system-context.md#4-trust-boundaries--the-list-phase-12-inherits).

The hybrid is only safe if the boundary is explicit, so it is stated as: **the client never writes
business data directly; it only subscribes and fetches.**

> ### 🟢 Resolution — Decided: Option C
> Hybrid, with the boundary stated exactly as above. Recorded in
> **[ADR-0001](../adr/ADR-0001-hybrid-api-and-direct-realtime-access.md)**.

---

## OD-04 · Do you accept the V1 scope boundary? — **Blocks Phase 02**

**Context.** You listed 62 modules. I have proposed shipping 16 in V1 and sequencing the remainder
across V2–V4, per [scope-and-release-slices.md](scope-and-release-slices.md). Nothing is cut —
everything stays on the roadmap.

**Why I am pushing on this.** Under our own Definition of Done, 62 modules is a multi-year build
with no real-shop feedback until the end. The likely failure is not building the wrong features;
it is never finishing any of them. Every product on your comparison list — Square, Loyverse,
Shopify POS — launched narrow and expanded.

**What I need from you:** approval of the V1 boundary, or a specific amendment. If you believe a
module I deferred is genuinely required for a shop to trade for one day, name it and I will move it
into V1 — that is exactly the right test to apply.

> ### 🟢 Resolution — Decided: V1 boundary accepted as proposed
> The 16-module V1 boundary in [scope-and-release-slices.md](scope-and-release-slices.md) stands.
> Phase 02 can proceed. If, once real requirements are being written, a specific V1 module turns
> out to need something from a deferred module to actually work for a full trading day, that's
> raised as a scoped amendment at that point — not a reason to revisit the whole boundary now.

---

## OD-05 · Multi-outlet in the data model from day one? — **Decide by Phase 07**

**Context.** V1 targets single-outlet shops. Multi-outlet ships in V4. But *the schema* must decide
now whether stock, sales and users are scoped to a store or to a tenant.

**My recommendation: yes — model it now, hide it in the interface.** Every stock and sales record
carries a `store_id` from the first migration; V1 simply creates one store per tenant and never
shows the selector. The cost is one column and some discipline. Retrofitting store scoping onto
live stock ledgers is among the most expensive migrations in this domain, and we would be doing it
precisely when we have customers to disrupt.

> ### 🟢 Resolution — Decided: yes
> Recorded in **[ADR-0003](../adr/ADR-0003-multi-outlet-modelled-from-day-one.md)**.

---

## OD-06 · What is your realistic time commitment? — **Blocks Phase 16**

**Context.** Milestones and sprint planning are fiction without a capacity number. I need hours per
week available for this project, and whether anyone else is contributing.

This does not change the architecture. It changes every date, and I would rather produce a schedule
you can actually hit than one that looks good in Phase 16 and is abandoned by Phase 18.

> ### 🟢 Resolution — Decided: solo, 10–20 hrs/week
> Answered directly by the founder when Phase 16 actually reached this gate (2026-07-31), rather
> than guessed at provisionally — see [capacity-model.md](../16-milestones/capacity-model.md) for
> why a placeholder here would have been worse than waiting. Converted into a real V1 schedule in
> [roadmap.md](../16-milestones/roadmap.md#4-converting-to-a-date--resolved): roughly Week 44–67
> (10–15 months) to a pilot-ready V1 at the midpoint pace, ~8 months–2 years across the full
> 10–20 hrs/week sensitivity band.

---

## Decision log

| ID | Decision | Status | Decided | Outcome |
| --- | --- | --- | --- | --- |
| OD-01 | Launch market | 🟡 Provisional | 2026-07-28 | Assumed India (GST) as a placeholder — **not confirmed**, correct me before Phase 02 content is treated as final |
| OD-02 | Hosting posture | 🟢 Decided | 2026-07-28 | Option B — see [ADR-0002](../adr/ADR-0002-hosting-posture-for-commercial-launch.md) |
| OD-03 | Direct platform access | 🟢 Decided | 2026-07-28 | Option C (hybrid) — see [ADR-0001](../adr/ADR-0001-hybrid-api-and-direct-realtime-access.md) |
| OD-04 | V1 scope boundary | 🟢 Decided | 2026-07-28 | Accepted as proposed, 16 modules |
| OD-05 | Multi-outlet in schema | 🟢 Decided | 2026-07-28 | Yes — see [ADR-0003](../adr/ADR-0003-multi-outlet-modelled-from-day-one.md) |
| OD-06 | Time commitment | 🟢 Decided | 2026-07-31 | Solo, 10–20 hrs/week — see [capacity-model.md](../16-milestones/capacity-model.md) |

Resolved decisions that are architecturally significant are promoted to ADRs in
[docs/adr/](../adr/) and this table links to them.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-28 | Initial draft, all six open. |
| 0.2.0 | 2026-07-28 | OD-02, OD-03, OD-04, OD-05 decided per founder instruction to proceed on recommendation. OD-01 set to provisional (India/GST assumed, unconfirmed). OD-06 remains open, non-blocking. |
| 0.3.0 | 2026-07-31 | OD-06 resolved when Phase 16 reached its gate — asked directly (not guessed): solo, 10–20 hrs/week. Only OD-01 remains open. |
