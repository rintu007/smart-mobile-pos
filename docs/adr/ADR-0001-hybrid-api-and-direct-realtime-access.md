# ADR-0001 — Mobile Client Uses API for Writes, Direct Platform Access Only for Realtime Reads and File Transfer

> **Status:** 🟢 Accepted
> **Date:** 2026-07-28
> **Phase:** 01 — Project Vision (resolves OD-03 ahead of Phase 07/11 so downstream phases aren't blocked)
> **Deciders:** CTO
> **Supersedes:** _none_

---

## Context

Supabase allows the Flutter client to reach PostgreSQL two ways: through our own Next.js API, or
directly via the Supabase SDK with Row Level Security (RLS) as the only gate. Using both paths for
overlapping purposes creates two authorisation models, two audit trails and two offline stories
that will eventually disagree — and in a multi-tenant POS, disagreement here means one shop reading
or writing another shop's data, which [project-vision.md](../01-vision/project-vision.md) §8
Principle 8 declares absolute.

At the same time, reimplementing Supabase Realtime's subscription mechanism behind our own API
would mean rebuilding a solved problem badly, for no isolation benefit if RLS is correctly applied.

## Decision drivers

- Business rules (stock movements, invoice numbering, tax calculation, returns eligibility) must
  not live in a client that a determined user can decompile and modify.
- Tenant isolation must be enforced in more than one independent layer (Principle 8; risk R-04).
- Realtime UI updates (stock changes, new orders) need low-latency push; funnelling that through a
  custom API layer duplicates Supabase's own mechanism at a real engineering cost.
- File transfer (receipts, product images) is a solved problem via signed URLs and shouldn't be
  proxied through application servers.

## Options considered

### Option A — API-only
All reads and writes go through the Next.js API.

| Pros | Cons |
| --- | --- |
| One authorisation model, one audit trail | We reimplement realtime subscriptions ourselves |
| Simplest mental model | Higher latency and engineering cost for no isolation benefit |

### Option B — Direct platform access for everything
Client uses the Supabase SDK directly for CRUD; RLS is the only authorisation layer.

| Pros | Cons |
| --- | --- |
| Fastest to build | Business rules end up in the client — an attacker's client, not just ours |
| | RLS becomes the *only* line of defence, violating the defence-in-depth stance |
| | No natural place for cross-entity business logic (e.g. "check stock before completing sale") |

### Option C — Hybrid with a strict, named boundary
All writes and all business logic go through the API. Realtime read subscriptions go direct,
secured by RLS. File upload/download go direct via short-lived signed URLs issued by the API.

| Pros | Cons |
| --- | --- |
| Business logic stays server-side and testable | Two code paths to reason about, so the boundary must be explicit and enforced |
| Realtime stays cheap and native | RLS policies must be correct on every table, since they're load-bearing for the read path |
| Defence in depth: API authorisation + RLS, independently | |

## Decision

We will adopt **Option C**, stated as a single, non-negotiable rule:

> **The mobile client never writes business data directly. It only subscribes and fetches.**

Concretely:
- All mutations (sales, stock movements, purchases, returns, settings changes) go through Route
  Handlers in the Next.js API. The API validates, applies business rules, and is the only writer of
  business tables.
- Realtime read subscriptions (e.g. live stock updates, new-order notifications) use the Supabase
  Realtime SDK directly from the client, gated by RLS.
- File transfer (receipt PDFs, product images) uses signed URLs issued by the API with short
  expiry; the client uploads/downloads directly to storage, never proxied through our servers.
- RLS is enabled and enforced on every tenant-scoped table regardless of this split — it is the
  independent second line of defence assumed in Principle 8, not a convenience for the read path.

## Consequences

**Positive**
- Business rules have exactly one home (the API service layer), which is where they're tested.
- Tenant isolation is enforced twice, independently: API-layer checks and RLS.
- Realtime UX is native-quality without us rebuilding pub/sub.
- The offline sync engine (Phase 13) has one clear counterpart to talk to for writes.

**Negative — accepted costs**
- Two authorisation surfaces to keep correct: API-layer checks and RLS policies. Both must be
  tested; RLS in particular needs the cross-tenant test suite mandated in
  [12-security/README.md](../12-security/README.md).
- Engineers must remember the rule; a mutation added via the direct SDK "because it was faster"
  is a policy violation, not a shortcut, and is treated as a defect in review.

**Neutral**
- This does not by itself decide multi-tenancy model or RLS policy shape — those are separate,
  still-open decisions in the [ADR backlog](README.md).

## Compliance

- Pull request review checklist: "does this change write business data via the Supabase SDK
  directly from the client?" — if yes, reject.
- Lint/CI rule (to be added in Phase 15): the mobile client's generated Supabase client is
  configured or wrapped such that write operations on business tables are not reachable from
  feature code, only from the sync/API layer.
- RLS cross-tenant test suite (Phase 12) runs on every migration and is a required CI status check.

## Revisit when

Realtime at scale proves RLS-gated subscriptions cannot meet latency or filtering needs the API
could meet better — or if Supabase itself is replaced (see hosting portability stance in
[ADR-0002](ADR-0002-hosting-posture-for-commercial-launch.md)).
