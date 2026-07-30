# Competitor Teardown

> **Status:** 🟢 Approved (as researched)
> **Version:** 1.0.0
> **Last updated:** 2026-07-29
> **Owner:** Product Manager
> **Sources checked:** 2026-07-29

---

## Loyverse — the closest architectural cousin

| | |
| --- | --- |
| **Model** | Genuinely free core POS (order taking, payments, reporting, inventory, employee management, a loyalty program) with paid add-ons (~$5/store or employee/month, ~$50/year) for advanced inventory, integrations. Paid plans from $29/month. |
| **Why it matters to us** | Loyverse proves a free-core, paid-add-on model works for this exact segment. It is also evidence *against* undifferentiated competition on price — we cannot out-free Loyverse's free tier, so free-tier price is not our wedge. |
| **Where we differ** | Loyverse's offline mode is best-effort/limited, not an architectural guarantee (this is widely reported by users, not independently verified against their current documentation in this pass — flag for direct testing in Phase 02 proper). No QR customer-facing ordering catalogue as a first-class feature. No purchase/supplier workflow depth. |

**Sources:** [Loyverse Pricing Guide (Loman)](https://loman.ai/blog/loyverse-pricing) ·
[Loyverse POS Pricing 2026 (getapp)](https://www.getapp.com/retail-consumer-services-software/a/loyverse-pos/)

---

## Vyapar — the India-specific GST incumbent

| | |
| --- | --- |
| **Model** | Android-primary GST billing/accounting app for Indian small business. Paid tiers roughly ₹1,999–₹6,800/year (sources vary; treat as directional, re-verify at pricing-strategy time). |
| **Why it matters to us** | Vyapar is the most direct existing answer to "GST billing on an Android phone for a small Indian shop" — exactly our provisional-market wedge. It is accounting/billing-centric, not POS-centric: built around invoicing and ledgers, not a fast counter-sale loop. |
| **Where we differ** | Vyapar is not architected offline-first as a POS till — it's an invoicing/accounting app that happens to run on mobile, not a queue-speed scan-and-sell counter tool. No customer-facing QR ordering. No stock-ledger-based inventory model (implementation detail, not independently confirmed). This is our clearest opening: **POS speed + GST compliance + true offline**, not accounting-app-with-a-billing-screen. |

**Sources:** [Vyapar Billing Software (Techjockey)](https://www.techjockey.com/detail/vyapar) ·
[Vyapar vs Accountune vs MyBillBook 2026 (accountune)](https://accountune.com/vyapar-vs-accountune-vs-mybillbook/)

---

## Zoho POS / Zoho Books

| | |
| --- | --- |
| **Model** | Starts around $9/5 users/month billed annually; deeply integrated into the broader Zoho suite (Books, Inventory, CRM). |
| **Why it matters to us** | Represents the "ecosystem lock-in" competitor — once a shop is in Zoho for accounting, POS is a natural upsell, not a standalone purchase decision. |
| **Where we differ** | Zoho's strength (deep suite integration) is also its weakness for our segment: it assumes the owner wants an accounting ecosystem, not a phone-first single app. Zoho is not offline-first by architecture. |

**Source:** [Zoho POS vs Competitors 2026 (magistrum)](https://www.magistrum.in/post/zoho-pos-vs-the-competition-a-deep-dive-for-indian-global-businesses-and-why-your-implementatio)

---

## Marg ERP — the inventory-depth incumbent (pharma/distribution-leaning)

| | |
| --- | --- |
| **Model** | One-time licence pricing (₹8,100–₹25,200) plus an annual maintenance contract (~₹3,500/year), not SaaS subscription. |
| **Why it matters to us** | Proves a one-time-purchase model still has demand in this market — worth noting as an alternate pricing shape, even though our stated business-model direction (see [project-vision.md §11](../01-vision/project-vision.md)) is subscription. Strong in batch/expiry tracking — exactly the pharmacy-vertical depth we've deliberately deferred to V4. |
| **Where we differ** | Desktop-rooted heritage, not mobile-first. Its strength (deep batch/expiry/serial tracking) is precisely the V4 vertical-specific territory we are deliberately not building first. |

**Source:** [Marg ERP Pricing India 2026 (itforsme)](https://www.itforsme.in/pricing/marg-erp-india/)

---

## Square, Shopify POS, Toast, Lightspeed — named in the founding brief, not directly comparable

Not re-researched in this pass — these are card-payment-subsidised, hardware-bundled products built
for markets with reliable card infrastructure and higher price tolerance, per
[project-vision.md §4](../01-vision/project-vision.md). They remain the *aspirational* comparison
for polish and completeness, not the *pricing* or *market* comparison — Vyapar and Loyverse are the
competitors an actual target shop is choosing between. Worth a direct teardown only if/when a
second launch market with card-dominant payments is decided.

---

## What this teardown means for positioning

| Competitor | Their strength | Our opening |
| --- | --- | --- |
| Loyverse | Generous free tier, polished POS UX | True offline-first architecture, not best-effort offline; QR customer ordering |
| Vyapar | GST compliance depth, India trust | POS-speed counter workflow, stock-ledger inventory, still GST-compliant |
| Zoho | Suite integration | Phone-first simplicity for an owner who doesn't want an accounting ecosystem |
| Marg ERP | Batch/expiry/serial depth | Mobile-first, subscription-simple, modern UX — depth is a V4 roadmap item, not a launch requirement |

No single competitor combines **true offline-first + POS-speed counter workflow + GST compliance +
mobile-native**. That combination is the positioning, not any single feature.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 1.0.0 | 2026-07-29 | Initial research pass. |
