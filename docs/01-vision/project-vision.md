# SmartPOS X — Project Vision

> **Status:** 🟢 Approved
> **Phase:** 01 — Project Vision
> **Version:** 1.0.0
> **Last updated:** 2026-07-28
> **Owner:** CTO / Product
> **Approved by:** Founder, 2026-07-28

---

## 1. Vision statement

> **Any small business owner, anywhere, can run their entire operation from the phone already in
> their pocket — and keep selling when the internet does not.**

## 2. Mission

Enable any small or medium business to run its entire operation using only an Android phone or
tablet, requiring zero technical knowledge. A shop owner installs the app, creates an account,
configures the shop in under ten minutes, and immediately starts selling.

## 3. Tagline

**SmartPOS X — The Complete Mobile First Business Management Platform.**

---

## 4. The problem we are solving

Small retailers are underserved from both directions.

**From above**, the established platforms — Shopify POS, Square, Toast, Lightspeed — are built for
markets with reliable card infrastructure, reliable internet, and businesses large enough to absorb
a per-terminal monthly fee plus hardware. They assume a counter, a till, a dedicated device, and a
staff member who can be trained. In a market where the "shop" is one person with a phone and a
drawer of cash, these products are not expensive so much as *irrelevant*.

**From below**, the free and cheap alternatives are ledger apps. They record what happened. They do
not run the business: no stock that decrements as you sell, no purchase orders, no supplier
balances, no returns that reverse the stock movement they created, no audit trail.

Between those, the specific unmet needs are:

| Problem | What it costs the business today |
| --- | --- |
| **Stock is unknown.** Nobody knows what is really on the shelf. | Dead capital in slow stock; lost sales on stock-outs; theft invisible. |
| **Internet is unreliable.** Cloud POS stops selling when the connection drops. | A POS that can stop selling is worse than a notebook. This is the single most common reason small retailers abandon a POS. |
| **Hardware is a barrier.** A terminal, a scanner, a printer and a PC is a serious capital outlay. | The business never adopts a POS at all. |
| **Software assumes literacy the owner does not have.** | Abandoned after week one. |
| **Returns, exchanges and warranty are handled on trust and memory.** | Fraud, disputes, and margin quietly lost. |
| **The owner cannot see the shop when they are not in it.** | The business cannot grow past one location or one trusted person. |

**Our wedge is the offline-first guarantee.** Everything else on this list is a feature someone
else also has. *"You never stop selling"* is a property of the architecture, and it is very hard
for an incumbent cloud POS to retrofit.

---

## 5. What we are building

A single Android-first application, backed by a cloud platform, that covers the operational spine
of a small retail or hospitality business:

- **Sell** — a point of sale that is faster than a calculator and works with no signal.
- **Know your stock** — inventory that is correct because every movement is recorded, not typed.
- **Buy** — suppliers, purchase orders, goods receipt, and what you owe.
- **Know your customers** — history, credit, loyalty.
- **Take it back** — returns, exchange, refund and warranty, with the stock and money reversed correctly.
- **See the truth** — reports the owner reads on their phone, not spreadsheets they export.
- **Sell without being there** — a per-shop QR catalogue customers browse and order from, with no app to install.

## 6. What we are explicitly not building

Stated now, because the fastest way to kill this product is to build all of it.

- **Not an accounting package.** We produce the data an accountant needs and export it. We do not
  do double-entry ledgers, journals, or statutory financial statements. Competing with established
  accounting software is a separate company.
- **Not an e-commerce platform.** The QR catalogue serves the shop's existing walk-in and local
  customers. It is not a storefront competing for search traffic.
- **Not an ERP.** No manufacturing, no bill of materials, no complex procurement approval chains.
- **Not desktop-first.** Web exists for what a phone genuinely does badly: bulk import, long
  reports, multi-outlet oversight. Every operational workflow works on the phone.
- **Not a payments company.** We integrate payment providers. We do not hold, move or settle funds.
  Doing so is a regulated activity in every market and would change what this company legally is.

---

## 7. Who it is for

**Primary — the owner-operator.** One to five staff, one to three outlets. Runs the shop and works
in it. Technology-cautious, price-sensitive, and has abandoned at least one business app before.
They are the buyer, the administrator and often the cashier. **If the product does not work for
them on day one without training, nothing else matters.**

**Secondary — the small chain.** Three to ten outlets, a manager per outlet, an owner who is no
longer behind the counter and needs to trust numbers they did not enter themselves. This segment
pays more and churns less, but we do not design for it first — designing for the chain produces
software the owner-operator cannot use, and we would lose both.

**Verticals at launch** are the ones whose core loop is *scan → price → take money → decrement
stock*: grocery and super shop, general retail, stationery, gift, toy, book, hardware, mobile and
electronics accessories, fashion.

**Verticals deferred**, because each carries regulatory or workflow requirements that are a product
in themselves: pharmacy (batch, expiry, controlled substances, prescriptions), restaurant and café
(tables, kitchen routing, courses, modifiers), salon (appointments, staff calendars, commission),
jewellery (weight-based pricing, live metal rates, hallmarking). These are on the roadmap. Building
them into V1 would mean shipping nothing well.

See [Scope & Release Slices](scope-and-release-slices.md) for the full boundary.

---

## 8. Product principles

These are decision rules. When two options conflict, the higher principle wins.

### 1. Never stop selling
The till works with no internet, no server, no account refresh. Offline is the *normal* operating
mode that happens to sync, not an error state we degrade into. Any feature that cannot work offline
must justify why, and must fail in a way that does not block a sale.

### 2. The sale is sacred
A recorded sale is never lost, never silently altered, never duplicated by a retry. Sales are
immutable once completed; corrections are new, linked, auditable events. This constrains the data
model and we accept that constraint.

### 3. Tap count is a specification, not an aspiration
Every primary workflow has a stated maximum tap count, measured and enforced. A cashier serving a
queue is the harshest usability test that exists. *Target: barcode → payment → receipt in three
taps.*

### 4. Correct beats convenient
Stock, money and tax are either right or the product is worthless. Where a shortcut would make the
interface nicer but the number less trustworthy, the number wins.

### 5. Zero technical knowledge required
No configuration screen may require understanding a technical concept. If a setting needs
explaining, either provide a working default or do not ship the setting. **Every setting we add is
a support ticket we will receive forever.**

### 6. Works on the phone they already own
A low-end Android device on a poor connection is the target, not the edge case. Performance is
measured there.

### 7. Boring, proven technology
This system holds other people's money and stock. We choose well-understood technology with large
communities and clear failure modes over anything novel.

### 8. Multi-tenant isolation is absolute
One shop must never, under any circumstance including a bug, see another shop's data. This is
enforced in more than one layer, on the assumption that any single layer will eventually be got wrong.

---

## 9. Architectural stance

Not a design — Phase 07 and Phase 11 own that. These are the positions the vision commits to,
because they determine whether the product can keep its promises.

| Stance | Why the vision requires it |
| --- | --- |
| **Offline-first, not offline-tolerant** | Principle 1. The local database is the source of truth for the till at the moment of sale; the server is the source of truth for the business. The design must reconcile those two honestly rather than pretending only one exists. |
| **Stock is an append-only ledger, never a mutable counter** | Two offline terminals both selling the last unit is not a merge conflict if each records "−1"; it is a merge conflict, and a corrupted count, if each records "quantity = 4". This single choice determines whether concurrent offline selling is correct or silently destructive. Candidate ADR. |
| **Every write is idempotent, keyed by a client-generated identifier** | An unreliable network means retries. Retries without idempotency mean double sales and double stock movements. |
| **Money is stored as integer minor units** | Floating-point money produces reconciliation errors that surface months later and destroy trust in every report. Non-negotiable. |
| **Authorisation is enforced server-side, and again at the database** | Principle 8. Client-side permission checks are user experience only. |
| **The mobile client talks to one API surface, not several** | If the client speaks to our API for some things and directly to the database platform for others, we have two authorisation models, two offline stories and two audit trails. See [open decision OD-03](open-decisions.md). |

---

## 10. Why we can win

We are not going to out-feature Shopify. We do not need to.

1. **Offline-first is architectural, not a feature.** Incumbents built cloud-first; retrofitting a
   true offline till means rewriting their data model. We get it by starting there.
2. **Zero hardware requirement.** Phone camera as scanner, cheap Bluetooth thermal printer as
   optional. The adoption barrier drops from significant capital to a free download.
3. **Underserved markets.** The businesses we target are not on the incumbents' roadmaps, because
   they cannot pay incumbent prices.
4. **Whole-operation coverage.** Competitors at our price point do sales *or* stock. Owners
   currently reconcile between apps by hand.
5. **The QR catalogue is free distribution.** Every shop that adopts it puts our product in front
   of its customers — who are themselves often small business owners.

**Where we are structurally weak, and must not pretend otherwise:** no card-payment revenue stream
to subsidise the software, no hardware business, no brand trust, and no field sales force. The
product must be good enough to be adopted without any of those.

---

## 11. Business model direction

Recorded as *direction*, not decision — pricing is Phase 02, and it depends on the launch market.

- **Free tier** — one outlet, one user, capped monthly transactions. Genuinely usable, not crippled.
  It is our distribution channel; a crippled free tier converts nobody.
- **Paid tier, per outlet per month** — multiple users, roles, unlimited transactions, full reports,
  QR ordering.
- **Never charged for:** the offline capability, or access to the business's own data. Holding a
  business's own sales history hostage is the practice that makes small retailers distrust POS
  vendors, and we will not adopt it.

The cost floor per tenant must be established in Phase 02 before pricing is set. See
[Risks, Constraints & Assumptions](risks-constraints-assumptions.md) — the "free services only"
constraint does not survive contact with paying customers, and pricing must account for that.

---

## 12. Ten-minute promise

The mission commits to "installs, configures and sells within ten minutes." That is a testable
requirement, and Phase 03 will hold us to it:

| Step | Budget |
| --- | --- |
| Install and open | 1 min |
| Create account and verify | 2 min |
| Choose business type — loads sensible defaults for tax, units, categories | 1 min |
| Shop name, currency, address | 2 min |
| Add first three products, or import a starter catalogue for that business type | 3 min |
| First sale, receipt printed or shared | 1 min |
| **Total** | **10 min** |

The design consequence: **onboarding must choose defaults for the owner, not ask them questions.**
Anything the owner is asked during setup must earn its place against this budget.

---

## 13. Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-28 | Initial draft for approval. |
| 1.0.0 | 2026-07-28 | Approved. |
