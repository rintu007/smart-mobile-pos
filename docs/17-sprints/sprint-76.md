# Sprint 76

> **Dates:** 2026-08-26 (single-day)
> **Milestone:** none — a documentation-only staleness audit, not milestone work
> **Status:** Closed. No code change.

## Goal

Continuing the founder-directed "audit a different phase" instruction, this sprint applied the same
discipline to Phase 13 (Offline Sync) — foundational documents that hadn't been touched since they
were first written (2026-07-31), predating almost all real implementation.

## What was found

Unlike Sprint 75's finding (a mechanism designed but never built), this sprint's findings are a
different, arguably more consequential shape: **a real, load-bearing safety claim that was simply
wrong**, propagated identically across three independent documents.

**`entity-classification.md §3` claimed `trading_days` was "conflict-free by construction" because
it was "scoped per-device," making concurrent writes to the same row structurally impossible.**
Checked directly against `schema-server.md` (itself already corrected on this exact point during
Sprint 69's own audit, which this document was never cross-checked against): `trading_days` was
never scoped per-device at all — Sprint 26 built it scoped by `(tenant_id, store_id)`, a real,
deliberate deviation named at the time. Under that real scoping, two devices at the same store
*can* genuinely race to write the same row — specifically, both attempting to open a new trading day
simultaneously. This is not a hypothetical: Sprint 26 built a real, hand-edited, database-level
guard against exactly this case — a partial unique index,
`CREATE UNIQUE INDEX trading_days_one_open_per_store ON trading_days(tenant_id, store_id) WHERE
status = 'open'` — confirmed directly in the migration file. The practical outcome this section
claimed (no duplicate-open-day problem) is correct; the *reason it's true* is a real, enforced
database constraint against a genuine race, not the race being structurally impossible. Telling a
reader "there is nothing here to design a policy for" when what actually exists is "here is the
policy, and it's a unique index" is a materially different, and more dangerous, thing to leave
standing in a document whose own charter says it's "the foundation everything else in this phase
builds on."

**The identical false claim was traced to two more documents and corrected in the same pass:**
`schema-local.md` (three separate references — a table row justifying `trading_days`' client-
editable classification, a table row describing what a device caches locally, and by extension the
reasoning behind both) and `entity-classification.md`'s own §2 table row. `offline-workflows.md`'s
original Finding 2 — the source of the underlying question — was checked and found still accurate:
it only ever posed the device-vs-store question, never asserted which one was chosen, so there was
nothing to correct there.

**A second, smaller but related class of finding, in the same two documents:** both
`entity-classification.md` and `schema-local.md` classified `idempotency_keys`/`sync_rejections` as
"server-only," implying a real server-side table a device simply doesn't need to read. Neither table
was ever actually built, on either side — already known and named correctly in `schema-server.md`
and (for `idempotency_keys` specifically) Sprint 41's own finding, just never carried into these two
documents' own classification tables.

**A third, mechanically verifiable completeness gap:** `entity-classification.md §2`'s own stated
exit criterion — "every one of the 22 tables... appears above exactly once, no entity is
unclassified" — stopped being true the moment `invoice_sequences` (Sprint 24), `customer_field_conflicts`
(Sprint 35), and `rate_limit_buckets` (Sprint 45) were built, none of which were ever added to this
classification table. All three added now, with a defensible classification for each.

**`conflict-resolution.md`** was checked separately and found to have a narrower, more contained
issue: its own field-edit-collision merge policy is designed for all five client-editable entities
it scopes itself to (`categories`, `units`, `products`, `customers`, `shop_settings`) but is only
actually *built* for `customers` (`customer.update`, Sprint 35 — this sync engine's only `.update`
operation type of any kind, confirmed by grep). The underlying gap (`categories`/`units`/`products`
having no edit endpoint at all yet) was already correctly named elsewhere (each module's own spec,
`modules/README.md`) — not new — but this specific document never stated it, reading as if the
described policy already applied uniformly.

## Design decisions

1. **Correct the reasoning, not just the label.** A simpler fix would have been to just change
   "conflict-free by construction" to "conflict-resolved" without explaining why the original
   mechanism claim was wrong — rejected, since a reader relying on this document to understand *why*
   trading-day conflicts don't happen needs the real mechanism (a database constraint), not a
   softened version of the same wrong story.
2. **Trace a finding to every document repeating it, not just the one first opened.** The trading-
   days error appeared identically in three places because `schema-server.md`'s own Sprint 69
   correction was never propagated outward to the documents that depend on it. This sprint closes
   that propagation gap explicitly, the same "who else claims this" check Sprint 74/75 both applied.
3. **Defensible classifications for the three newly-added tables, not left unclassified again.**
   `invoice_sequences` and `rate_limit_buckets` fit existing classes reasonably cleanly
   (server-authoritative; sync-mechanism-infrastructure, respectively). `customer_field_conflicts`
   doesn't fit any of the four classes perfectly (it's server-generated, pulled and resolved, but
   never client-created or client-edited) — named as such explicitly rather than forced into an
   ill-fitting category for the sake of tidiness.

## Definition of Done

- [x] `docs/13-offline-sync/entity-classification.md` — §2's table and §3 both corrected; 3 missing
      tables added; version bumped 0.1.0 → 0.2.0.
- [x] `docs/13-offline-sync/conflict-resolution.md` — intro corrected to state actual per-entity
      build status; version bumped 0.1.0 → 0.1.1.
- [x] `docs/07-database/schema-local.md` — three references to the same false trading-days claim
      corrected, plus the idempotency_keys/sync_rejections mischaracterization; version bumped
      0.1.6 → 0.1.7.
- [x] `offline-workflows.md` checked and confirmed to need no correction — it never asserted the
      false resolution in the first place.
- [x] Every claim verified against real code or a prior sprint's own already-corrected source before
      being written: the actual migration file for `trading_days_one_open_per_store`, a grep for any
      `.update` sync operation type besides `customer.update`, `schema-server.md`'s own already-
      corrected Context 5/7 entries.
- [x] `git status` confirms only `docs/` files touched — no code, matching this sprint's own stated
      documentation-only scope.
- [x] `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md` updated in the
      same PR.

## Demo script

**Local, run 2026-08-26:**

1. Re-read `schema-server.md`'s own already-corrected `trading_days` entry (Sprint 69) before
   touching any of the three documents in this sprint, to correct against the verified-true account
   rather than re-deriving it from scratch. ✅
2. Confirmed the real partial unique index directly in
   `apps/web/prisma/migrations/20260814050000_add_trading_days/migration.sql` — not assumed from a
   prior summary. ✅
3. `grep "\.update'" apps/web/src/modules/sync/service.ts apps/web/src/modules/sync/schema.ts` —
   confirmed `customer.update` is the only hit. ✅
4. Checked `offline-workflows.md`'s original Finding 2 text directly before deciding it needed no
   correction, rather than assuming every document touching this topic was equally wrong. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Worth naming plainly: this sprint is a direct consequence of a gap Sprint 69's own retrospective
already predicted but didn't chase — "no mechanism in this project currently checks that a module
spec's own named deviation from `schema-server.md` actually gets mirrored back." That's exactly what
happened here, three times over, with the exact same root fact (`trading_days`' real scoping). A
correction made once, in the one document most directly about the schema, doesn't automatically
reach every other document that independently restated the same fact for its own purposes. Worth
considering, the next time a foundational fact like this is corrected: a deliberate "who else states
this" grep, in the same sprint, rather than trusting that a single correction propagates on its own.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-26 | Sprint 76: found and corrected a real, load-bearing false safety claim, not just staleness — `trading_days` was documented in three places (`entity-classification.md`, `schema-local.md` ×2, plus `conflict-resolution.md`'s narrower related finding) as "conflict-free by construction" via per-device scoping; it's actually scoped per-store with a real database-level unique-index guard against a genuine concurrent-open race. Also corrected `idempotency_keys`/`sync_rejections` mischaracterization (never built, not "server-only") and added 3 tables missing from `entity-classification.md`'s own "every entity classified" exit criterion. `offline-workflows.md` checked and confirmed accurate, needing no change. No code change. |
