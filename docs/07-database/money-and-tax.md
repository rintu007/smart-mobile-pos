# Money & Tax — Precision, Rounding, Worked Examples

> **Status:** 🔵 In review
> **Phase:** 07 — Database Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** PostgreSQL Architect / CTO
> **Approved by:** _pending_

Representation is fixed by [ADR-0006](../adr/ADR-0006-money-as-integer-minor-units.md). This
document specifies the **arithmetic** to the minor unit, with worked examples, per this phase's exit
criterion. All examples use the provisional currency (INR, minor unit = paise, 100 paise = ₹1) —
provisional on [OD-01](../01-vision/open-decisions.md) like everything else tied to the launch
market.

---

## 1. The rule, restated precisely

A discount reduces the **taxable value** — tax is charged on the discounted price, not the original
price. This is stated explicitly here because it wasn't pinned down anywhere earlier in the
documentation set and money-and-tax arithmetic cannot be specified without it:

```
line_subtotal_minor_units  = ROUND(unit_price_minor_units × quantity, rounding_rule)
line_taxable_value         = line_subtotal_minor_units − line_discount_minor_units
line_tax_minor_units       = ROUND(line_taxable_value × tax_rate_basis_points / 10000, rounding_rule)
line_total_minor_units     = line_taxable_value + line_tax_minor_units

invoice.subtotal_minor_units   = Σ line_taxable_value           (post-discount, pre-tax)
invoice.tax_total_minor_units  = Σ line_tax_minor_units          (never independently rounded — DR-008)
invoice.discount_total_minor_units = Σ line_discount_minor_units
invoice.grand_total_minor_units    = invoice.subtotal + invoice.tax_total
```

Two rounding steps exist, not one: `line_subtotal_minor_units` rounds a fractional-quantity
multiplication to a whole minor unit (relevant whenever a unit like kilogram is fractional,
[FR-037](../03-functional-requirements/functional-requirements.md)); `line_tax_minor_units` rounds
the tax computation itself. Both use the **same shop-configured `rounding_rule`**
([FR-075](../03-functional-requirements/functional-requirements.md)) — a shop cannot mix rounding
methods between the two steps.

## 2. Rounding rules offered

| Rule | Behaviour at exactly .5 | Notes |
| --- | --- | --- |
| `round_half_up` (default) | Rounds away from zero | Matches common commercial/retail expectation; recommended default for [FR-075](../03-functional-requirements/functional-requirements.md). |
| `round_half_even` ("banker's rounding") | Rounds to the nearest even value | Statistically unbiased over many transactions; offered for shops or auditors who specifically expect it. |

Both are exact, deterministic operations over integers — neither involves floating-point
arithmetic at any step, per [ADR-0006](../adr/ADR-0006-money-as-integer-minor-units.md).

## 3. Worked example — exclusive pricing, three lines, mixed tax rates, a discount, and a fractional quantity

Shop: `pricing_mode = 'exclusive'`, `rounding_rule = 'round_half_up'`.

| Line | Product | Unit price | Qty | Discount | Tax rate | Subtotal (rounded) | Taxable value | Line tax | Line total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Rice | 5,000 paise/kg | 2.500 kg | 0 | 5% (500 bp) | 5,000 × 2.500 = **12,500** | 12,500 | ROUND(12,500 × 0.05) = **625** | 13,125 |
| 2 | Biscuits | 1,200 paise/pack | 3 | 200 paise | 18% (1800 bp) | 1,200 × 3 = **3,600** | 3,600 − 200 = **3,400** | ROUND(3,400 × 0.18) = **612** | 4,012 |
| 3 | Loose tea | 333 paise/unit | 0.500 | 0 | 12% (1200 bp) | ROUND(333 × 0.500) = ROUND(166.5) = **167** | 167 | ROUND(167 × 0.12) = ROUND(20.04) = **20** | 187 |

```
invoice.subtotal_minor_units       = 12,500 + 3,400 + 167   = 16,067 paise  (₹160.67)
invoice.discount_total_minor_units = 0 + 200 + 0            =    200 paise  (₹2.00)
invoice.tax_total_minor_units      = 625 + 612 + 20         =  1,257 paise  (₹12.57)
invoice.grand_total_minor_units    = 16,067 + 1,257         = 17,324 paise  (₹173.24)
```

**Verification of [DR-008](../03-functional-requirements/business-rules.md):** summing the three
line totals directly — `13,125 + 4,012 + 187 = 17,324` — matches `grand_total_minor_units` exactly.
This is not a coincidence to be re-checked by hand each time; it is the property the property-based
test in [QA-010](../04-srs/quality-attributes.md) asserts across generated inputs.

**Why line 3 matters:** `333 × 0.500 = 166.5` is not a whole number of paise — this is where a
fractional-quantity unit forces a real rounding decision, not just a tax-rate rounding decision.
Under `round_half_even` instead, `166.5` rounds to `166` (the nearest even value) rather than `167`,
shifting the final invoice by 1 paise. **This is exactly why the rounding rule must be fixed and
shop-configured, never mixed** — [FR-076](../03-functional-requirements/functional-requirements.md).

## 4. Worked example — inclusive pricing (tax already in the displayed price)

Same Rice line, but now `pricing_mode = 'inclusive'` and the ₹50.00/kg price already includes 5% tax:

```
line_gross_minor_units = unit_price_minor_units × quantity = 5,000 × 2.500 = 12,500 paise (rounded, as before)
line_taxable_value     = ROUND(line_gross_minor_units / (1 + tax_rate), rounding_rule)
                        = ROUND(12,500 / 1.05) = ROUND(11,904.7619...) = 11,905 paise
line_tax_minor_units   = line_gross_minor_units − line_taxable_value   = 12,500 − 11,905 = 595 paise
```

**Tax is computed as the residual** (`gross − taxable`), not by re-multiplying the rounded taxable
value by the rate — `11,905 × 0.05 = 595.25`, which would not sum back to the displayed gross total
exactly. Defining tax as the residual guarantees `taxable + tax = gross` holds exactly, always, at
the cost of the *effective* rate on the rounded taxable value being very slightly off nominal — an
accepted, standard trade-off, stated explicitly here rather than left as an unexplained discrepancy
if someone checks the arithmetic by hand later.

## 5. What this document does not decide

The **default** tax rates and rounding rule per business type, and the exact list of supported tax
rates, are populated by [seed-data.md](seed-data.md) and ultimately require the standing
GST-practitioner review before being treated as compliant, per
[regulatory-requirements.md](../02-business-requirements/regulatory-requirements.md).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial money/tax arithmetic specification with worked exclusive and inclusive examples. Discount-before-tax rule stated explicitly for the first time. |
