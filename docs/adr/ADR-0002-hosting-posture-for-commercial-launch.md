# ADR-0002 — Free Tiers for Development and Pilot, Budgeted Paid Tier at Commercial Launch

> **Status:** 🟢 Accepted
> **Date:** 2026-07-28
> **Phase:** 01 — Project Vision (resolves OD-02 ahead of Phase 02/12 so downstream phases aren't blocked)
> **Deciders:** CTO
> **Supersedes:** _none_

---

## Context

The founding brief constrains this project to free, open-source services wherever possible. That
constraint holds cleanly through development and pilot. It does not survive commercial launch
unmodified, for reasons documented in
[risks-constraints-assumptions.md §R-01](../01-vision/risks-constraints-assumptions.md):

1. Several platforms' free tiers are licensed for **non-commercial use only** — deploying
   revenue-generating software on them is a licence breach, not a resource-limit problem, and the
   typical remedy is suspension without notice.
2. Managed-database free tiers commonly **pause on inactivity** and cap storage/egress. A paused
   database is a shop that cannot sync — which directly violates the "never lose a sale" promise.
3. Public map tile servers (e.g. the OSM Foundation's community tiles) explicitly prohibit heavy or
   commercial-scale use; they are donated infrastructure, not a free CDN.

Payment processing is separately, unavoidably, never free — every provider charges per transaction.
That cost is accepted as a cost of the V3 slice and is not part of this decision.

**These specific licence and limit terms must be re-verified against current vendor documentation
during Phase 02** (see [reference/README.md](../reference/README.md)) — they are cited here as the
category of risk, not as verified current facts, and change without notice.

## Decision drivers

- Free-tier resource limits and licence terms change without notice and are not something to
  discover at the moment a real customer's shop goes down.
- The founder's instruction to prefer free and open-source services is real and should be honoured
  everywhere it does not conflict with the product's core promise (never stop selling).
- A small team cannot absorb an emergency migration under load; a scheduled one is manageable.
- The vision explicitly states we will never hold a business's own data hostage — infrastructure
  fragility that causes downtime is a version of that same failure from the customer's perspective.

## Options considered

### Option A — Free tiers throughout, accept the boundary reactively
| Pros | Cons |
| --- | --- |
| Zero cost until forced | Forced migration happens under time pressure, likely mid-growth, likely badly |
| | Licence breach risk is live from the first paying customer, not from the migration date |

### Option B — Free for development and pilot, budgeted paid production tier at launch
| Pros | Cons |
| --- | --- |
| Predictable, small, known cost from day one of commercial operation | Real (if modest) recurring cost — see [OD-02 budget question](../01-vision/open-decisions.md) |
| No launch-day infrastructure crisis | |
| Standard, boring, well-understood practice | |

### Option C — Self-host on a single small VPS
| Pros | Cons |
| --- | --- |
| Lowest fixed cost, full control | Team owns backups, patching, uptime, scaling — real operational burden for a small team |
| | Higher time cost than money cost, which is the scarcer resource here |

## Decision

We will adopt **Option B**: free-tier services through development and pilot; a modest budgeted
paid production tier from the point of commercial launch (first paying customer, not first pilot
shop). The architecture is deliberately kept portable so Option C remains available as an escape
hatch rather than a rebuild:

- Standard PostgreSQL — no proprietary compute primitives (stored procedures tied to one vendor,
  vendor-specific extensions in business-logic paths) in anything the domain layer depends on.
- Containerisable Next.js API — deployable to any container host, not wired to one platform's
  edge-function dialect for anything load-bearing.
- Supabase used for what it is genuinely strong at (Postgres, Auth, Realtime, Storage) behind our
  own service-layer interfaces (consistent with [ADR-0001](ADR-0001-hybrid-api-and-direct-realtime-access.md)),
  so a future platform swap is a migration, not a rewrite.

Map tiles for delivery tracking (V3) will use a provider with explicit commercial terms, not the
public OSM community tile servers, when that feature is built.

## Consequences

**Positive**
- No forced emergency migration at the worst possible moment — the first busy trading day of a
  paying customer.
- Licence compliance is designed in rather than discovered as a problem after the fact.
- Portability means a vendor's pricing or policy change becomes a scheduled project, not a crisis.

**Negative — accepted costs**
- A real, if modest, monthly infrastructure cost from commercial launch. This must be reflected in
  the [cost model](../02-business-requirements/README.md) that underpins pricing — see
  [success-metrics.md §5](../01-vision/success-metrics.md), "infrastructure cost per active shop
  per month" is now a required, not optional, input to pricing.
- Slightly more deployment complexity than "use every default" — connection pooling, environment
  separation, and a portability discipline that must be maintained deliberately (it erodes quietly
  if unreviewed).

**Neutral**
- The exact budget ceiling is still an open input from the founder ([OD-02](../01-vision/open-decisions.md))
  — this ADR fixes the *posture*, not the number.

## Compliance

- Phase 02 cost model must cite current, dated vendor pricing and licence terms, not assumptions.
- Code review rejects any dependency on a vendor-proprietary compute primitive in the domain layer
  (per [ways-of-working.md §7](../00-governance/ways-of-working.md)).
- `reference/vendor-limits.md` (Phase 02 deliverable) is the source of truth for current limits and
  is re-verified every six months per [reference/README.md](../reference/README.md).

## Revisit when

Actual infrastructure cost per tenant, once measured in pilot, makes Option B's price point
incompatible with the pricing strategy — or a specific vendor policy change forces the portability
escape hatch to be exercised.
