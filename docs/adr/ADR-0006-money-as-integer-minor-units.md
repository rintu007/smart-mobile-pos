# ADR-0006 — Money Stored as Integer Minor Units; Tax Rates as Integer Basis Points

> **Status:** 🟢 Accepted
> **Date:** 2026-07-30
> **Phase:** 07 — Database Design
> **Deciders:** CTO / PostgreSQL Architect
> **Supersedes:** _none_

---

## Context

[DR-010](../03-functional-requirements/business-rules.md) already states the rule: money is an
integer count of the currency's minor unit, never a floating-point value, anywhere in the pipeline.
This ADR is the formal ratification the decision backlog required, now made concrete at the column
level, since "never floating point" has to resolve to an actual Postgres type and an actual
tax-rate representation before a migration can be written.

**Why this needs to be an ADR, not just a rule stated once:** floating-point money is the single
most common data-correctness defect in commercial software of this kind, and it is invisible in
development — `0.1 + 0.2` looking wrong only shows up as a reconciliation discrepancy months later,
at the exact moment [BR-041](../02-business-requirements/business-requirements.md) (non-zero cash
variance) is supposed to be trustworthy. The cost of getting this wrong is paid entirely by the
shop owner's trust in the numbers, per [project-vision.md §8](../01-vision/project-vision.md)
Principle 4.

## Decision drivers

- [DR-008](../03-functional-requirements/business-rules.md) requires per-line tax rounding with an
  exact, reproducible result — impossible to guarantee with binary floating point.
- [QA-010](../04-srs/quality-attributes.md) requires invoice tax totals to be *exactly* the sum of
  rounded per-line taxes, verified across a property-based test sweep — "exactly" is not a
  meaningful word applied to a `float`/`double`.
- Multiple currencies are not a V1 concern, but the representation should not preclude it later.

## Options considered

### Option A — `NUMERIC`/`DECIMAL` column storing a decimal amount (e.g. `19.99`)
| Pros | Cons |
| --- | --- |
| Human-readable in a raw query | Still requires a rounding-rule decision at every arithmetic step; easy to accidentally cast through a floating type in application code (ORMs are a common culprit) |

### Option B — Floating-point (`FLOAT`/`DOUBLE PRECISION`)
| Pros | Cons |
| --- | --- |
| None worth listing | Binary floating point cannot exactly represent most decimal fractions; ruled out categorically, not weighed against the other options |

### Option C — `BIGINT` storing an integer count of the currency's minor unit (e.g. paise, cents)
| Pros | Cons |
| --- | --- |
| Exact arithmetic using ordinary integer operations — no rounding ambiguity in storage | Less human-readable in a raw query (requires dividing by 100, or by the currency's minor-unit factor, at display time) |
| Trivially portable across currencies with different minor-unit factors (paise=2 decimal places, but the pattern generalises) | Every layer (database, API, mobile) must consistently apply the same minor-unit convention |

## Decision

We will adopt **Option C**. Every monetary column is `BIGINT`, storing an integer count of the
configured currency's minor unit (paise, for the provisional India market). Tax **rates** are
stored as integer **basis points** (`INTEGER`, e.g. `1800` = 18.00%) for the same reason — a
percentage stored as `0.18` is still a decimal-fraction representation with the same rounding
hazard money has.

Concretely, per [DR-008](../03-functional-requirements/business-rules.md):
```
line_tax_minor_units = ROUND(line_taxable_value_minor_units × tax_rate_basis_points / 10000, rounding_rule)
invoice.total_tax_minor_units = SUM(line.tax_minor_units)   -- never independently rounded
```
Full worked examples, rounding-rule options, and per-line vs per-invoice arithmetic are specified in
[money-and-tax.md](../07-database/money-and-tax.md) — this ADR fixes the *representation*, that
document fixes the *arithmetic*.

## Consequences

**Positive**
- Arithmetic is exact integer arithmetic at every layer — no representation-induced rounding error
  is possible, only rounding-*rule* decisions, which are explicit and testable.
- The same convention (integer minor units, integer basis points) applies uniformly across
  Postgres, the Next.js/TypeScript API, and the Flutter/Dart mobile client — one rule, not three.

**Negative — accepted costs**
- Every developer must remember the convention; a raw `price / 100.0` in application code
  displaying, rather than computing, an amount is fine — a stored or computed value that
  accidentally becomes a float anywhere in the arithmetic chain is a defect, and this is a discipline
  cost enforced by code review and, where feasible, strong typing (a `Money` value type wrapping
  the integer, not a bare `int`/`number`, in both TypeScript and Dart) rather than by convention
  alone.
- Multi-currency support (not a V1 feature) would need a currency code alongside every amount to
  know its minor-unit factor — not designed for now, not precluded either.

**Neutral**
- This does not decide the rounding *rule* itself (round-half-up, round-half-even, etc.) — that is
  a shop-configurable setting per [FR-075](../03-functional-requirements/functional-requirements.md),
  specified in [money-and-tax.md](../07-database/money-and-tax.md).

## Compliance

- Every migration adding a monetary column is reviewed against: "is this `BIGINT` in minor units,
  not `NUMERIC`/`FLOAT`/`DOUBLE`?" A violation blocks the migration.
- A `Money` value type (or equivalent strong-typing pattern) is used in both the TypeScript API and
  Dart mobile code so that an accidental float conversion is a type error, not a silent runtime bug
  — an implementation-time requirement carried into Phase 08/18.
- Property-based tests (per [QA-010](../04-srs/quality-attributes.md)) assert exact equality between
  summed line-level tax and invoice-level tax across generated inputs.

## Revisit when

Multi-currency support is scoped — at that point this ADR is extended (not superseded) to add a
currency code alongside the minor-unit convention, which the integer representation already
accommodates without a structural change.
