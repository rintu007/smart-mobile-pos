# Migration Strategy

> **Status:** 🔵 In review
> **Phase:** 07 — Database Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** PostgreSQL Architect / DevOps Engineer
> **Approved by:** _pending_

The specific challenge this document addresses: a schema change ships to the server the moment it's
deployed, but a mobile app update reaches each device only when that device's owner updates it —
which, for a shop that's busy, might be weeks. **The server must never require every device to be
on the latest app version at the same moment**, or a migration becomes an outage for anyone who
hasn't updated yet.

---

## 1. The governing rule: expand, migrate, contract — never break in place

Every schema change that isn't purely additive follows three steps, as separate deployments, never
collapsed into one:

1. **Expand** — add the new column/table alongside the old one. Both old and new app versions keep
   working unmodified; the new column is nullable or defaulted so old write paths don't need to
   know about it.
2. **Migrate** — backfill existing data into the new shape; update the API to read/write the new
   shape while still tolerating the old one from app versions that haven't updated.
3. **Contract** — once telemetry shows no meaningful traffic from app versions using the old shape
   (a policy threshold, not yet fixed — see §4), remove the old column/table in a final migration.

A rename, a type change, or a column removal is **never** done as a single migration — each is
three, run at least one app-release-cycle apart from each other.

## 2. Purely additive changes — the common case

Adding a new table, or a new nullable column with a sensible default, requires no expand/contract
dance — this is the majority of expected V1-era schema evolution (e.g. the
`product_variants`/`batches` stub tables already added now, per this phase's own exit criterion, are
exactly this: additive, unused by current app versions, ready for a future one).

## 3. Local (Drift/SQLite) migrations

Drift's own schema-versioning mechanism (`schemaVersion` + `onUpgrade` migration steps) runs when
an updated app first opens on a device. Two rules, specific to this product's offline-first
architecture, beyond Drift's normal usage:

- **A local migration must never drop or truncate `outbound_queue`.** A device migrating its local
  schema may be holding unsynced sales — per [BR-004](../02-business-requirements/business-requirements.md),
  losing them is the one failure mode the entire product exists to prevent. Every local migration
  is tested against a fixture database containing non-empty `outbound_queue` rows, asserting they
  survive intact.
- **A local migration must not require connectivity to complete.** The app must open and function
  (including draining any pending queue) immediately after an update, even if the device is offline
  at that moment — consistent with [FR-009](../03-functional-requirements/functional-requirements.md).

## 4. Open policy question — how many app versions does the server support at once?

**Not yet resolved.** The API is already committed to versioning from day one
([11-api charter](../11-api/README.md)), but the specific policy — how long an old app version
continues to sync successfully before the server requires an update, and what a device sees when
that window has passed — is not decided in this phase. Flagged forward to Phase 11 (API design) and
Phase 15 (release/CI process), because it's simultaneously an API contract question and an
operational one, not purely a schema question. **What must not happen:** a device silently failing
to sync with no explanation because its app is "too old" — whatever the policy turns out to be, the
failure mode must be a clear, actionable message, not a silent stall.

## 5. Migration review checklist (applies to every migration, referenced from this phase's exit criteria)

- [ ] Is this migration additive, or does it need the expand/migrate/contract pattern?
- [ ] Does every new tenant-owned table have `tenant_id NOT NULL` and an RLS policy in the same
      migration ([ADR-0004](../adr/ADR-0004-shared-schema-multi-tenancy.md))?
- [ ] Does every new store-scoped table have `store_id NOT NULL` ([ADR-0003](../adr/ADR-0003-multi-outlet-modelled-from-day-one.md))?
- [ ] Is the table classified Tier 1 (soft delete) or Tier 2 (no delete), with the corresponding
      grants set correctly ([ADR-0009](../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md))?
- [ ] Does the cross-tenant negative-read test suite pass against the new/changed table
      ([tenancy-model.md](tenancy-model.md))?
- [ ] Is every index in the migration traceable to a specific query in a specific workflow
      ([schema-server.md](schema-server.md))? A speculative index is removed before merge, per this
      phase's exit criteria.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial migration strategy: expand/migrate/contract pattern, Drift-specific safety rules, migration review checklist. Version-support-window policy flagged open for Phase 11/15. |
