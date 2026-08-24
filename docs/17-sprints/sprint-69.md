# Sprint 69

> **Dates:** 2026-08-25 – 2026-08-25 (single-day, same cadence as every prior sprint)
> **Milestone:** none — a Phase 07 documentation audit, self-initiated after the Dependabot triage
> (Sprints 66–68) left no unstarted engineering work and the founder directed the session to
> continue rather than hold
> **Status:** Closed. No code change.

## Goal

With the 12-PR Dependabot triage fully closed and no engineering work left in M5 (backlog.md §6 is
entirely founder-owned actions), this session re-audited earlier phases for the same class of
"design doc vs. built reality" drift that Sprints 50–61 repeatedly found and fixed in the
release-readiness-critical documents. Those sprints never touched Phase 07 (`schema-server.md`)
itself — the single most foundational database design document, and, per this document's own
"deviations from the specification update the specification" rule, the one every implementation-time
schema deviation is supposed to flow back into. It had never been checked against the live schema in
one pass since it was first written.

## What was found

A line-by-line reconciliation of every table in Context 2 (Catalogue) through Context 6 (Returns)
against the actual `apps/web/prisma/schema.prisma`, cross-checked against module specs and live
query code where a claim was ambiguous — not assumed correct because it read plausibly.

**The most significant finding:** `device_id` is documented as a real, `NOT NULL` column on
`stock_movements`, `trading_days`, and `sales` — none of the three ever actually got it. `devices`
wasn't built until Sprint 55, many sprints after all three tables existed, and none were retrofitted.
`trading_days`' own entry spent a full paragraph justifying per-device scoping as the built design;
the real, built design is `(tenant_id, store_id)` scoping, a genuine Sprint 26 deviation already
named and reasoned in [trading-day/specification.md §1](../modules/trading-day/specification.md#1-purpose-and-business-context)
— but that correction was never carried back to `schema-server.md`, this project's own stated source
of truth, leaving the master design doc wrong for 42 sprints.

**The same shape, a second time:** `client_operation_id` is documented as a real column on
`stock_movements`, `sales`, and `returns`. None of the three built it — `id` alone (client-generated
per ADR-0007) is the idempotency key on all three, a decision already correctly reasoned in the
`Return` Prisma model's own comment ("the documented separate `client_operation_id` column is
dropped... matching every other client-generated-id table's actual working mechanism") but, again,
never carried back to `schema-server.md`.

**Three real, built, live production tables were never added to the document at all:**
`invoice_sequences` (Sprint 24, ADR-0008's canonical invoice-number counter), `customer_field_conflicts`
(Sprint 35, the conflict-resolution field-merge), `rate_limit_buckets` (Sprint 45, server-side rate
limiting) — each has its own migration, RLS policy (or a reasoned exception, for the last one), and
multiple sprints of live-verified behaviour, yet none has ever had its own entry here. The document's
own "22 tables" count was never updated to reflect them.

**Smaller, adjacent drift found while working through the same tables carefully:** `sales.trading_day_id`
documented `NOT NULL`, actually nullable (Sprint 26's deliberate decision); `sales.financial_year`
missing from the column list entirely (Sprint 24); `products.category_id`/`unit_id` documented
`NOT NULL`, actually nullable (Sprint 19); `customers.erased_at`/`updated_by` missing (Sprints 46/35);
`sale_line_items.quantity`/`stock_movements.quantity_delta` documented `NUMERIC(14,3)`, actually
`INTEGER` (already correctly named in `inventory/specification.md §3`, just not carried back here).

**Four indexes and one column documented but never built, found and deliberately *not* fixed
speculatively:** `sales(customer_id)` (customer purchase history — a real, live, unindexed query,
confirmed by reading `customers/repository.ts#listPurchaseHistory` directly), `sale_line_items(product_id)`
(top/slow product reports), `products(tenant_id, name text_pattern_ops)` and
`products(tenant_id, category_id)` (both genuinely exercised by `GET /api/v1/products`'s real
`search`/`category_id` filters, confirmed by reading `products/repository.ts` directly — not the
mobile-till's own separate, correctly-local search this document's earlier sprints referenced), and
`sale_line_items.hsn_sac_code_at_sale` (RR-003's per-line GST snapshot, never built). These are real,
live, buildable gaps — additive, low-risk migrations, unlike the RLS-FORCE question's genuine
production-outage risk — but adding a migration is its own kind of change needing its own dedicated
verification, not something to fold into a documentation-only pass. Named here, left for a focused
follow-up sprint.

## Design decisions

1. **Bound the audit deliberately rather than chase every lead to exhaustion.** Every corrected claim
   above was found while working through Contexts 2–6 in real detail; Context 1 (Identity & Tenancy)
   and 7 (Settings & Sync) were checked only for the specific `device_id`/table-count issues already
   being tracked, not re-audited from a blank slate. Stated explicitly in the document's own Change
   Log rather than silently implying full coverage — the same honesty this project's own "not pilot-
   ready today" release-checklist findings have always insisted on.
2. **Fix documentation-only drift in this pass; name real code gaps for a separate one.** The
   `device_id`/`client_operation_id`/missing-table corrections are pure documentation fixes — the
   live system already behaves the corrected way, only the design doc was wrong. The missing indexes
   and the `hsn_sac_code_at_sale` column are different in kind: fixing them means writing and
   verifying a real migration against a live database, the same distinction Sprint 62 (documentation)
   drew against Sprints 63/64 (real fixes) when re-examining the OWASP findings.
3. **Correct every table's entry fully once touched, not partially.** Having already opened
   `sales`'s entry to fix `trading_day_id`, the missing `financial_year` column and stray
   `client_operation_id` claim were fixed in the same edit rather than left for a future pass to
   rediscover — the same "while you're in there" discipline Sprint 65 applied to `backlog.md`'s own
   stale intro paragraph.
4. **A lead surfaced but not chased: `tenant-isolation.md`'s own CI-suite table count.** That
   document tracks a separately-maintained tenant-owned-table count for the cross-tenant RLS test
   suite (currently "20 of 20" as of Sprint 55) — it's not yet checked whether `invoice_sequences`/
   `customer_field_conflicts` (both genuinely tenant-owned, both documented here as RLS: tenant-
   scoped) are actually included in that suite's coverage. Real, worth checking, explicitly not
   investigated this sprint to keep this one bounded — named for a focused follow-up.

## Definition of Done

- [x] `docs/07-database/schema-server.md` — `device_id`/`client_operation_id` false claims corrected
      across `stock_movements`/`trading_days`/`sales`/`returns`; three missing tables added
      (`invoice_sequences`, `customer_field_conflicts`, `rate_limit_buckets`); table count corrected
      22 → 25; five smaller column/type discrepancies corrected; four missing indexes and one missing
      column named as real, deferred follow-up work rather than fixed speculatively.
- [x] Every new/edited cross-reference link checked against its target document's actual heading
      text before being committed — two links (`identifiers.md`, `privacy.md`) simplified to
      file-only links after their target headings' em-dashes made the exact anchor slug ambiguous to
      verify by hand.
- [x] `git status` confirms only `docs/` files touched — no code, no migration, matching this
      sprint's own stated documentation-only scope.
- [x] `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md` updated in the
      same PR.

## Demo script

**Local, run 2026-08-25:**

1. Listed every real model in `apps/web/prisma/schema.prisma` (`grep '^model '`) and compared the
   count and names directly against `schema-server.md`'s own claimed table list — found the 3 missing
   tables this way, not by reading prose. ✅
2. For every table with an ambiguous or surprising claim, read the actual Prisma model definition
   (and its own doc comments, several of which already correctly named the deviation) before writing
   any correction — never corrected from memory or assumption. ✅
3. For the `sales.customer_id` and `products` search/category-filter index questions specifically,
   read the actual repository query code (`customers/repository.ts#listPurchaseHistory`,
   `products/repository.ts`) to confirm the query paths are real and live before naming the missing
   index as a real gap rather than a moot one. ✅
4. Verified every new cross-reference anchor against the target file's actual `## ` heading text
   before committing — caught and fixed three wrong anchors (`inventory/specification.md`,
   `identifiers.md`, `privacy.md`) this way. ✅

**Not performed this sprint, by design:** any migration, any index creation, any code change of any
kind — this is a documentation-only correction pass; the real, buildable gaps it found are named,
not fixed, pending their own dedicated verification.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Worth stating plainly: this project's own explicit rule — "deviations from the specification update
the specification, in the same pull request" — was violated repeatedly and for a long time in exactly
the place that rule matters most, the master database design document, without ever being caught by
any of this session's prior 68 sprints' worth of cross-document consistency checks. Every one of
those checks (Sprints 58–61) was aimed at release-readiness-critical documents — the OWASP checklist,
the release gate, the milestone exit criteria — never at the earlier, foundational design phases
those later documents all ultimately rest on. The lesson isn't that Phase 07 was neglected out of
carelessness — most individual deviations were reasoned and documented carefully, right at the module
spec that made them — it's that "the spec is updated in the same PR" needs to mean *every* spec a
deviation touches, including the one furthest upstream, not just the nearest one. No mechanism in
this project currently checks that a module spec's own named deviation from `schema-server.md`
actually gets mirrored back — this sprint found five instances of exactly that gap by hand, in one
pass, in tables nobody had reason to suspect were wrong until someone actually opened the file next
to the real schema and read both at once.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-25 | Sprint 69 (Phase 07 documentation audit, no code change): the first line-by-line reconciliation of `schema-server.md` against the live schema since it was written. Found and corrected `device_id`/`client_operation_id` false claims on `stock_movements`/`trading_days`/`sales`/`returns` (real Sprint 26/implementation deviations already reasoned in module specs, never carried back to this document); added 3 real tables never in the original design (`invoice_sequences`, `customer_field_conflicts`, `rate_limit_buckets`); corrected the table count from 22 to 25; fixed five smaller column/type discrepancies. Found and named, not fixed: 4 missing indexes and 1 missing column that are real, live, buildable gaps needing their own dedicated migration sprint. Also found a lead worth a focused follow-up: whether `tenant-isolation.md`'s own CI-suite table count actually covers the two newly-documented tenant-owned tables. |
