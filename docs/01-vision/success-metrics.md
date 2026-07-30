# Success Metrics

> **Status:** 🟢 Approved
> **Phase:** 01 — Project Vision
> **Version:** 1.0.0
> **Last updated:** 2026-07-28
> **Owner:** CTO / Product
> **Approved by:** Founder, 2026-07-28

---

## 1. Why this document exists before any code

A metric chosen after launch is chosen to flatter the result. Choosing now — while we have no data
and no ego invested — is the only time we can be honest about what would prove us wrong.

Every metric below is required to be **instrumentable from V1**. If we cannot measure it with the
data the product already records, it is not a metric, it is a hope.

---

## 2. North Star

> **Weekly Transacting Shops** — the number of distinct shops that recorded **20 or more sales** in
> a rolling 7-day window.

**Why this one.** It cannot be gamed by downloads, sign-ups, or a burst of curiosity. A shop that
rings up 20 real sales in a week has replaced its notebook or its previous POS. That is the only
event that matters. Registrations, installs and "active users" all move for reasons unrelated to
whether the product works.

**Why 20.** It is roughly three sales a day — below the volume of even a quiet shop, so it excludes
evaluation and tinkering, while not excluding genuinely small businesses. This threshold is a
hypothesis and is reviewed after the pilot; if pilot shops cluster differently, the number moves,
and that change is documented rather than quietly applied.

---

## 3. Product health metrics

Grouped by the promise each one tests. Each has a target for the pilot (first ~20 shops) and a
target for general availability.

### The ten-minute promise

| Metric | Definition | Pilot target | GA target |
| --- | --- | --- | --- |
| Time to first sale | Account creation → first completed sale | median ≤ 15 min | median ≤ 10 min |
| Onboarding completion rate | Shops completing setup ÷ shops starting | ≥ 70% | ≥ 85% |
| Setup abandonment step | The step with the highest drop-off | identified | no single step > 10% drop |

### The never-stop-selling promise

| Metric | Definition | Pilot target | GA target |
| --- | --- | --- | --- |
| **Sales lost to system failure** | Sales that were attempted but not recorded, for any reason | **0** | **0** |
| Offline sale share | Sales completed with no connectivity ÷ all sales | measured | measured |
| Sync success rate | Queued operations that reach the server without manual intervention | ≥ 99.5% | ≥ 99.9% |
| Sync latency | Connectivity restored → queue drained, p95 | ≤ 60 s | ≤ 30 s |
| Duplicate sale rate | Sales written twice by retry | **0** | **0** |
| Unresolved sync conflicts | Conflicts requiring a human decision, per 1,000 operations | ≤ 1 | ≤ 0.1 |

The first and last rows in this table are the product. If either is non-zero at GA, we do not
launch — we fix. This is the one place where a metric has veto power over a release date.

### Speed at the counter

| Metric | Definition | Pilot target | GA target |
| --- | --- | --- | --- |
| Taps to complete a cash sale | Barcode scanned → receipt, one item | ≤ 4 | **≤ 3** — the GA figure is [BR-011](../02-business-requirements/business-requirements.md)'s formal Must-requirement bar; ≤ 4 here is a deliberate, named allowance for the Pilot phase specifically, not a separate or looser requirement |
| Barcode scan → item on screen | p95, low-end device | ≤ 800 ms | ≤ 500 ms |
| Product search → result | p95, catalogue of 5,000 items | ≤ 400 ms | ≤ 250 ms |
| POS screen cold start | App launch → ready to scan, p95 | ≤ 3 s | ≤ 2 s |
| Sale commit (local) | Payment confirmed → receipt renders | ≤ 300 ms | ≤ 200 ms |

Measured on the **reference low-end device** defined in Phase 14, not on a development machine.

### Trust in the numbers

| Metric | Definition | Pilot target | GA target |
| --- | --- | --- | --- |
| Stock accuracy | Physical count matching system count, by SKU | ≥ 95% | ≥ 98% |
| Cash reconciliation variance | Drawer count vs system expected, per closing | ≤ 1% of takings | ≤ 0.5% |
| Report dispute rate | Owner-reported "this number is wrong" per shop per month | ≤ 0.5 | ≤ 0.1 |

### Retention

| Metric | Definition | Pilot target | GA target |
| --- | --- | --- | --- |
| Week-1 retention | Shops transacting in week 1 after onboarding | ≥ 60% | ≥ 75% |
| Week-4 retention | Still transacting in week 4 | ≥ 40% | ≥ 60% |
| Month-6 retention | Still transacting at month 6 | — | ≥ 50% |
| Second-user adoption | Shops that add a second staff account | ≥ 20% | ≥ 35% |

Second-user adoption is a leading indicator of durable retention: a shop that has trained a
cashier on the product has paid a switching cost it will not casually repeat.

---

## 4. Engineering health metrics

The product cannot stay good if the codebase does not. Reviewed monthly.

| Metric | Target |
| --- | --- |
| Crash-free session rate | ≥ 99.5% |
| Crash-free user rate | ≥ 99.9% |
| API availability | ≥ 99.5% monthly |
| API p95 latency | ≤ 400 ms |
| Unhandled server error rate | ≤ 0.1% of requests |
| CI pipeline duration | ≤ 10 min |
| Test coverage on business rules | ≥ 90% (branch coverage on domain logic; UI excluded) |
| Modules meeting Definition of Done | 100% — a module below it is not counted as delivered |
| Open critical security findings | 0 |
| Documentation drift | 0 merged pull requests with behaviour change and no documentation change |

---

## 5. Business metrics

Deliberately thin at this stage — pricing is a Phase 02 decision and depends on the launch market.
Listed so instrumentation is designed in, not bolted on.

| Metric | Note |
| --- | --- |
| Free → paid conversion | Target set in Phase 02 |
| Infrastructure cost per active shop per month | **Must be known before pricing.** See [risks](risks-constraints-assumptions.md) — this number decides whether the business model works. |
| Monthly recurring revenue | Post-launch |
| Churn, monthly | Target ≤ 5% |
| Support tickets per shop per month | ≤ 0.5. Higher means the product is asking too much of the owner — a design defect, not a support problem. |

---

## 6. Anti-metrics

Numbers we will **not** optimise, recorded so nobody is tempted when a chart looks flat.

| Anti-metric | Why we refuse it |
| --- | --- |
| App downloads / installs | Measures marketing, not product. Trivially inflated. |
| Registered accounts | A shop that signed up and never sold is a failure, and this number calls it a success. |
| Time in app / session length | For a POS, **less is better**. A cashier spending longer in our app is a cashier serving fewer customers. Optimising this would actively harm users. |
| Screens per session | Same inversion — more navigation means we hid something. |
| Feature count | The brief lists 62 modules; shipping all of them badly is not success. |
| Lines of code / commits / velocity points | Measures activity, not delivery. |

---

## 7. Review cadence

| Cadence | What is reviewed |
| --- | --- |
| Weekly | North Star, sync success, crash-free rate, sales lost to failure |
| Per sprint | Engineering health, Definition-of-Done compliance |
| Monthly | Retention cohorts, support-ticket rate, cost per shop |
| Per phase | Whether these metrics are still the right metrics |

A metric that has not changed a decision in three months is either already satisfied or was never
worth tracking. It is retired, and the retirement is recorded here.

---

## 8. Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-28 | Initial draft. |
| 1.0.0 | 2026-07-28 | Approved. |
