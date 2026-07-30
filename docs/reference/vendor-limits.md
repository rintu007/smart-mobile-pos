# Vendor Limits & Licence Terms

> **Status:** 🟢 Approved (as researched)
> **Version:** 1.0.0
> **Last updated:** 2026-07-29
> **Owner:** CTO
> **Sources checked:** 2026-07-29 — re-verify within six months per [reference/README.md](README.md)

This document exists to replace assumption with fact for [R-01](../01-vision/risks-constraints-assumptions.md#r-01--free-tier-constraint-does-not-survive-commercial-launch--priority-20-i5--l4)
and [ADR-0002](../adr/ADR-0002-hosting-posture-for-commercial-launch.md). Every figure below is a
claim about a vendor's *current* terms — vendors change these without notice, so treat anything
here as stale after six months and re-check before relying on it for a launch decision.

---

## Vercel

| | |
| --- | --- |
| **Hobby (free) tier** | Explicitly restricted to personal, non-commercial projects. Vercel's Terms of Service prohibit revenue-generating or business use on Hobby — this is a **licence violation**, not a resource-limit problem, and the stated remedy is loss of access, not a warning. |
| **Pro tier** | $20 per seat per month, includes a monthly usage credit; typical realistic all-in cost with bandwidth/function/edge overage lands closer to $60–70/month for an active small production app. |
| **Consequence for us** | Confirms [ADR-0002](../adr/ADR-0002-hosting-posture-for-commercial-launch.md): Hobby is a *development* tier only. The Next.js API **must** run on Pro (or a self-hosted container, per the portability stance) from the point any real customer starts paying us — not from the point we exceed a resource limit. |

**Sources:** [Vercel Pricing Explained (Kuberns)](https://kuberns.com/blogs/vercel-pricing/) ·
[Vercel Pricing 2026 (projectcostestimator)](https://projectcostestimator.com/blog/vercel-cost-2026) ·
[Vercel Pricing Plans and Hidden Costs (schematichq)](https://schematichq.com/blog/vercel-pricing)

---

## Supabase

| | |
| --- | --- |
| **Free tier** | 500 MB database, 1 GB file storage, 5 GB egress/month, 50,000 monthly active users, 500,000 edge-function invocations, up to 2 active projects. No credit card required. |
| **Inactivity pause** | A free project with **no API requests for 7 days is automatically paused.** Data is retained but the project goes offline until manually resumed — this alone is disqualifying for production use, independent of any licence question, because a paused database is a shop that cannot sync. |
| **Other free-tier gaps** | No automated backups, no SLA, no SSO. |
| **Pro tier** | $25/month baseline; removes the inactivity pause and raises every quoted limit. |
| **Consequence for us** | Confirms [ADR-0002](../adr/ADR-0002-hosting-posture-for-commercial-launch.md). Supabase free tier is fine for development and even early pilot (if we accept that inactive pilot shops may need a manual resume — acceptable for a handful of hand-held pilot shops, **not** acceptable once shops are trading unattended). Pro is required no later than commercial launch. |

**Sources:** [Supabase Free Tier Limits (itpathsolutions)](https://www.itpathsolutions.com/supabase-free-tier-limits) ·
[Supabase Pricing 2026 (makerkit)](https://makerkit.dev/blog/saas/supabase-pricing) ·
[Supabase Pricing 2026 (metacto)](https://www.metacto.com/blogs/the-true-cost-of-supabase-a-comprehensive-guide-to-pricing-integration-and-maintenance)

---

## Map tiles (OpenStreetMap community servers)

| | |
| --- | --- |
| **Policy** | OSM's donated community tile servers (`tile.openstreetmap.org` and regional equivalents) are funded by donations with limited capacity. Their own policy says commercial services "may no longer be able to serve paying customers if access is withdrawn," and access can be revoked **without notice** for heavy use. Some regional tile services require **written permission** for any revenue-generating use. Offline caching/downloading is explicitly disallowed on the main tile server. |
| **Consequence for us** | Confirms the concern in [ADR-0002](../adr/ADR-0002-hosting-posture-for-commercial-launch.md): the public OSM tile servers are not a free CDN for a commercial delivery-tracking feature (V3). OSM *data* remains free and open (ODbL) — only the donated *tile-serving infrastructure* is restricted. |
| **Viable alternative** | MapTiler's free tier: 100,000 tile requests/month, no credit card, hard-stops (no surprise billing) rather than overage charges. Paid tier from roughly €25/month. MapTiler also offers self-hosted tile serving (MapTiler Server) built on OSM data, which fits our portability stance. |

**Sources:** [OSMF Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/) ·
[OpenStreetMap US Tileservice usage policy](https://tiles.openstreetmap.us/usage-policy/) ·
[Mapbox vs MapTiler 2026 (shyft)](https://shyft.ai/tools/compare/mapbox-vs-maptiler) ·
[Best Mapbox Alternatives 2026 (buildmvpfast)](https://www.buildmvpfast.com/alternatives/mapbox)

**Note:** map tiles are a **V3** concern (delivery tracking), not V1. Recorded now so the decision
backlog entry in [docs/adr/README.md](../adr/README.md) has real numbers when V3 planning starts.

---

## Distribution

| | |
| --- | --- |
| **Google Play Console** | One-time **US $25** registration fee. No annual renewal, no per-app fee. (Contrast: Apple charges $99/year — irrelevant to us at launch since [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md) is Android-first by decision, not oversight.) |
| **Domain (.in)** | Roughly **₹350–900/year** (~US $4–11/year) at a standard registrar for renewal pricing; first-year promotional prices (sometimes ₹99) are not representative of ongoing cost. A `.com` runs somewhat higher, roughly ₹1,400/year at the same registrar. |

**Sources:** [Google Play Developer Fee 2026 (iconikai)](https://www.iconikai.com/blog/google-play-developer-account-fee-2026) ·
[Domain Price List India 2026 (ChennaiHost)](https://www.chennaihost.com/domains-price-list.html) ·
[Domain cost per year in India (seekahost)](https://www.seekahost.in/how-much-domain-cost-per-year/)

---

## Payment processing (never free — accepted cost of V3)

| | |
| --- | --- |
| **UPI (bank-to-bank, RuPay debit)** | Zero MDR is government-mandated on the underlying rail — banks cannot charge for the transfer itself. |
| **Gateway platform fee** | Aggregators (e.g. Razorpay) still charge a platform/technology fee on top of "free" UPI — commonly cited around **2%**, plus 18% GST *on that fee* (not on the transaction). |
| **Card/other methods via aggregators** | Typically **1.99%–3.5% + GST** depending on method and volume tier. |
| **Consequence for us** | This is a transaction-linked variable cost, not a fixed infrastructure cost — it belongs in the V3 pricing model as a pass-through or margin line, not in the monthly per-tenant hosting figure in [cost-model.md](../02-business-requirements/cost-model.md). |

**Sources:** [UPI Transaction Charges 2026 (Razorpay)](https://razorpay.com/learn/upi-transaction-charges/) ·
[Razorpay Payment Gateway Charges 2026 (softwaresuggest)](https://www.softwaresuggest.com/blog/razorpay-payment-gateway-charges/) ·
[Low Cost Payment Gateway in India 2026 (Razorpay)](https://razorpay.com/blog/low-cost-payment-gateway-in-india-the-complete-decision-guide/)

---

## Push notifications

Firebase Cloud Messaging remains free with no published send-volume cap for standard messaging —
this is consistent with the founding brief's assumption and was not re-verified with a fresh source
in this pass. **Flagged for verification** in Phase 11/12 before being relied on as a permanent
zero-cost line, since Google has changed adjacent Firebase pricing (e.g. Cloud Messaging's legacy
API deprecation) before.

---

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 1.0.0 | 2026-07-29 | Initial research pass supporting Phase 02 cost model and ADR-0002. |
