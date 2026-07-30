# Personas

> **Status:** 🟡 Draft — research-grounded, **not yet validated against real people**
> **Phase:** 05 — User Personas
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Product Manager / UI-UX Lead
> **Approved by:** _pending — cannot be approved until at least 3 personas are validated per this phase's exit criteria_

Seven personas, grounded in [market-analysis.md](../02-business-requirements/market-analysis.md),
[competitor-teardown.md](../reference/competitor-teardown.md), and the founding brief's target-user
list — not invented. **None of these has been validated against a real person yet.** That is a
genuine, unmet exit criterion, not a formality — see the note at the end of this document before
using these personas to settle a design argument you actually care about.

Three (**Owner, Manager, Cashier**) are V1-immediate and drive current design decisions. The other
four (Inventory Staff, Delivery Staff, Accountant, End Customer) are included now because the
charter asks for the full target-user list, but their design weight is lower until their release
slice (V2–V4) actually starts.

---

## Owner — V1-immediate

**Snapshot.** Runs a single-outlet shop (grocery, general retail, stationery, mobile accessories,
or similar — the V1 target verticals). Often works the counter personally, especially during rush
hours or when short-staffed; checks the shop's numbers from home in the evening.

| | |
| --- | --- |
| **Goals** | Know, without effort, whether today made money. Trust that staff aren't quietly costing them margin. Spend minimal time on anything that isn't selling. |
| **Frustrations** | Previous software (if any) was either too complex, required constant internet, or was in a language/interface that assumed more literacy or English fluency than they have. Staff either don't use a system correctly or actively route around it. |
| **Technical confidence** | Comfortable with WhatsApp, UPI payment apps, and basic smartphone use. Not comfortable with anything resembling a desktop-style interface, multi-step configuration, or technical vocabulary (this is exactly why [BR-002](../02-business-requirements/business-requirements.md) requires a working tax-status default rather than a technical question). |
| **Device & context** | A mid-range Android phone in the ₹13,000–25,000 band ([device-landscape.md](../reference/device-landscape.md)); sometimes an older, shared family device. Checks the app standing behind the counter between customers, or from home in the evening — both short, interrupted sessions, not long focused ones. |
| **Primary workflow & tap budget** | Checking the day's sales / stock position — [BR-042](../02-business-requirements/business-requirements.md)/[FR-071](../03-functional-requirements/functional-requirements.md). Target: the answer to "did today go well?" is visible within 2 taps of opening the app, with no export step. |
| **Design implication** | Onboarding must choose defaults for them, never ask a technical question with no good default ([project-vision.md §12](../01-vision/project-vision.md)). Reports must answer "how is my business doing" at a glance, not require interpretation. |

## Manager — V1-immediate

**Snapshot.** Second-in-command in a slightly larger V1 shop, or an Owner's trusted staff member who
opens/closes the register and oversees one or more Cashiers.

| | |
| --- | --- |
| **Goals** | Keep the shift running without needing to call the Owner for every judgment call. Catch a Cashier's mistake before it becomes the Owner's problem. Not be blamed for a shortfall that wasn't their fault. |
| **Frustrations** | No visibility into what's happening at the till until something has already gone wrong. Approval workflows that require leaving the floor or finding a manager-only terminal. |
| **Technical confidence** | Moderate — more comfortable with the app than a Cashier, by virtue of using it daily across more of its features (discount/return approval, day close). |
| **Device & context** | Personal or shop-issued phone; on their feet, moving between the till and the back room. |
| **Primary workflow & tap budget** | Approving a discount or return that exceeds the Cashier's threshold — [BR-015](../02-business-requirements/business-requirements.md)/[BR-038](../02-business-requirements/business-requirements.md). Target: 1–2 taps once the approval prompt appears; the Manager should never need to navigate away from wherever they already are to approve. |
| **Design implication** | The approval flow must interrupt the Manager's current screen with a request, not require them to go find a "pending approvals" screen — a Manager on the shop floor won't check a queue proactively during a rush. |

## Cashier — V1-immediate, **veto power over POS design**

**Snapshot.** Operates the till directly. Frequently young, sometimes part-time or seasonal,
sometimes minimally trained (a 10-minute walkthrough from the Owner is a realistic upper bound, not
a worst case).

| | |
| --- | --- |
| **Goals** | Serve the next customer fast. Not make an embarrassing mistake in front of a waiting queue. Not be blamed for a register discrepancy at day close. |
| **Frustrations** | A barcode that won't scan under queue pressure. A slow or confusing screen. Having to interrupt a Manager mid-queue to resolve something the app should have handled. |
| **Technical confidence** | Comfortable with basic smartphone apps (messaging, social media) but has **no formal POS training** — this persona cannot be designed for as if they read a manual, because in the realistic case, they did not. |
| **Device & context** | Shop-provided phone, sometimes low-end, sometimes shared across shifts with other cashiers. Standing, often in a noisy environment (customers, street noise), with variable lighting — bright glare near a shop entrance, dim toward the back. Frequently one-handed (the other hand is holding a product, a bag, or cash) and under direct, visible time pressure from a waiting customer. |
| **Primary workflow & tap budget** | A single-item cash sale, scan to receipt, in **3 taps or fewer** — [BR-011](../02-business-requirements/business-requirements.md)/[QA-008](../04-srs/quality-attributes.md). This is the hardest usability bar in the entire product. |
| **Design implication** | **This persona has veto power over POS design**, per this phase's charter rule. If a POS design choice would not survive a noisy queue, one working hand, glare, and zero training, it is wrong regardless of how it tests in a quiet office. |

## Inventory Staff — V1 job function, not a system role

**Snapshot.** Someone — sometimes the Owner, sometimes dedicated staff in a larger V1 shop —
responsible for receiving stock, doing counts, and flagging damaged or expired goods. Operates
under a Cashier or Manager account in V1; see
[user-stories.md](../03-functional-requirements/user-stories.md) on why this is a function, not a
fourth role, in V1.

| | |
| --- | --- |
| **Goals** | Keep stock counts accurate without it consuming the whole day. Not be blamed for shrinkage that happened before their shift. |
| **Frustrations** | Adjustment reasons that are unclear or too granular; a workflow that assumes both hands are free when they're often carrying boxes. |
| **Technical confidence** | Variable — often lower than a Cashier's, since this role skews toward warehouse/back-room work rather than customer-facing, tech-adjacent tasks. |
| **Device & context** | Shared shop tablet or phone, often in a back room or storage area with worse lighting than the sales floor. |
| **Primary workflow & tap budget** | Recording a stock adjustment with a reason — [BR-023](../02-business-requirements/business-requirements.md)/[FR-043](../03-functional-requirements/functional-requirements.md). Target: ≤5 taps — less time-critical than a POS sale, but still fast enough not to be abandoned mid-task by someone with their hands full. |
| **Design implication** | Reason selection should be large touch targets, few enough options to scan quickly, and forgiving of one-handed operation. |

## Delivery Staff — V3, anticipatory only

**Snapshot.** Not present in V1. Included because the founding brief names this actor and because
anticipating their needs now avoids a V3 design surprise.

| | |
| --- | --- |
| **Goals (anticipated)** | Know which orders to deliver and where. Confirm delivery quickly without a phone call to the customer. |
| **Frustrations (anticipated)** | Unclear addresses, no map integration, needing a phone call to confirm a location. |
| **Technical confidence** | Likely moderate-to-comfortable with navigation apps (personal use of maps is already common), lower confidence with the delivery-tracking app itself if it's unfamiliar. |
| **Device & context** | Personal phone, likely used on a two-wheeler between stops (per [device-landscape.md](../reference/device-landscape.md) market context) — outdoor lighting, glare, one-handed use while stationary between rides. |
| **Primary workflow & tap budget** | Anticipated: mark an order delivered / capture proof of delivery, target ≤3 taps — **not a committed number**, since V3's own requirements phase hasn't run. Recorded here only so it isn't forgotten. |
| **Design implication** | None binding yet — revisit when V3 scoping starts. |

## Accountant — V2+, consumes exports, not the app itself

**Snapshot.** Likely external or part-time, engaged periodically rather than daily. Per
[project-vision.md §6](../01-vision/project-vision.md) — "not an accounting package" — this persona
is served by clean exports, not by operating the POS.

| | |
| --- | --- |
| **Goals (anticipated)** | Get clean, complete export data (sales, tax, expenses) without manually re-entering it into their own accounting software (commonly Tally or Zoho Books in the provisional market). |
| **Frustrations (anticipated)** | Missing HSN codes, inconsistent tax categorisation, data that requires cleanup before it's usable. |
| **Technical confidence** | High with spreadsheets and accounting software; likely low engagement with the mobile POS UI itself — this persona may never open the app. |
| **Device & context** | Desktop or laptop, not mobile. This is the one persona for whom [project-vision.md](../01-vision/project-vision.md)'s "desktop must not be required" applies differently — their need is a reporting/export consumption need, which is why a lightweight export view exists at all, not a contradiction of mobile-first for operational workflows. |
| **Primary workflow & tap budget** | Exporting a period's sales/tax data. **Tap count is the wrong measure for this persona** — the relevant quality bar is export completeness and correctness, not speed of interaction. Deliberately excluded from the tap-count framework rather than forcing a number that wouldn't mean anything. |
| **Design implication** | Not yet binding — V2+ scope. Recorded so export design doesn't start from zero when that phase arrives. |

## End Customer — passive in V1, active in V3

**Snapshot.** The person being sold to. In V1 they never authenticate or interact with the app
directly — they receive a receipt. In V3 (QR ordering) they become an active, if anonymous, actor.

| | |
| --- | --- |
| **Goals** | Get a receipt they can trust. Have a record of the purchase for a possible return, exchange, or warranty claim later. |
| **Frustrations** | Illegible receipts, long queues, no digital record if the paper receipt is lost. |
| **Technical confidence** | Assume the full range of general smartphone literacy — **do not assume tech-savviness**, since this persona is the general public, not a trained staff member. |
| **Device & context** | In V1: irrelevant — no device interaction. In V3 (anticipated): their own phone, scanning a QR code, likely a similar device profile to the Owner/Cashier persona given the same market. |
| **Primary workflow & tap budget** | V1: none — passive recipient of BR-033/BR-034 (printed or shared receipt). V3 (anticipated): scan → browse → order, tap budget not yet set — deferred to V3 scoping. |
| **Design implication** | The receipt itself (paper or digital) is this persona's entire V1 experience of the product — [10-design-system's receipt-design.md](../10-design-system/README.md) carries real weight here even though this persona never opens the app. |

---

## What is missing — read before using these to settle a real argument

**None of the seven personas above has been validated against a real person.** They are built from
desk research ([market-analysis.md](../02-business-requirements/market-analysis.md),
[competitor-teardown.md](../reference/competitor-teardown.md), the founding brief), not from talking
to an actual shop owner, cashier, or inventory staffer. This phase's own exit criteria require **at
least three personas validated against real people** before this document can be marked 🟢 Approved
— that requirement is unmet, and unlike the GST-practitioner review or the OD-01 market
confirmation, it cannot be satisfied by more desk research. It requires someone to have a real
conversation with a real shop.

**What validation would concretely look like:** 3–5 short interviews each with people matching the
Owner, Manager, and Cashier personas (the three that drive current design decisions), checking
whether their actual goals, frustrations, device, and context match what's written above — and
correcting whatever doesn't. This overlaps directly with the pilot-shop recruitment already planned
in [16-milestones](../16-milestones/README.md) — it does not need to wait for that phase to start
if any of these conversations are reachable sooner. The earlier this happens, the less of Phases
06–10 (which will be built assuming these personas are roughly right) needs rework.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial 7 personas, research-grounded, explicitly unvalidated. |
