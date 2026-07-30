# Authorisation Model

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Security Engineer / CTO
> **Approved by:** _pending_

Roles, permissions, enforcement points, and evaluation order — the mechanism behind the Permission
column that already appears on every row of [endpoints/](../11-api/endpoints/README.md), made
explicit as its own model rather than left implicit per-endpoint.

---

## 1. Roles — no new ones invented here

Cashier, Manager, Owner — the three system roles fixed in
[permission-matrix.md](../05-personas/permission-matrix.md) and [DR-019](../03-functional-requirements/business-rules.md)–[DR-021](../03-functional-requirements/business-rules.md).
This document does not add a fourth; per [user-stories.md](../03-functional-requirements/user-stories.md)'s
persona-vs-role clarification, personas like Inventory Staff or Delivery Staff map onto these three
system roles rather than each getting their own authorisation identity — a distinction this phase
inherits, not re-opens.

## 2. Evaluation order — every request, in this sequence, fail-closed at every step

```
1. JWT signature and expiry verified            → fail: UNAUTHENTICATED / TOKEN_EXPIRED
2. Device revocation checked (devices.revoked_at) → fail: DEVICE_REVOKED
3. tenant_id resolved from the JWT claim          → fail: UNAUTHENTICATED (claim absent/malformed)
4. Current role resolved: user_store_roles         → fail: PERMISSION_DENIED (no active role at this store)
   WHERE user_id = ? AND store_id = ? AND revoked_at IS NULL
5. Endpoint's required permission checked against  → fail: PERMISSION_DENIED
   the resolved role (static per-endpoint table, §3)
6. Action-specific business-rule checks run in     → fail: the specific DR-NNN's own error code
   service.ts (e.g. DR-013 return-quantity limit)   (e.g. RETURN_QUANTITY_EXCEEDS_SOLD)
7. Row Level Security re-checks tenant_id (and      → fail: empty result set, indistinguishable
   store_id where applicable) at the database         from NOT_FOUND
```

**Fail-closed, stated as a binding rule per this phase's own founding rule:** any error, exception,
or unexpected condition at any step **denies** the request. There is no step in this sequence where
an exception is caught and treated as "allow" — a bug that causes step 4's lookup to throw is a
`500 INTERNAL`, never a silent fall-through to step 5.

## 3. Enforcement points — three, not one, deliberately redundant

| Layer | What it checks | Bypassable by |
| --- | --- | --- |
| **Client (mobile app)** | Whether to show/enable a control at all — [guards-and-redirects.md](../09-navigation/guards-and-redirects.md)'s permission guard | Trivially, by a modified client — this layer is **user experience only**, per this phase's exit criterion, never trusted for actual authorisation |
| **API — Route Handler middleware, step 5 above** | The static permission required for this endpoint, evaluated **before** the handler's own logic runs, from one central per-endpoint permission table (mirroring the Permission column already declared per endpoint in [endpoints/](../11-api/endpoints/README.md)) | Not bypassable without a code change; this is the authoritative check for "can this role call this endpoint at all" |
| **API — service layer, step 6** | Business-rule-specific authorisation that isn't a flat role check (e.g. [LAST_OWNER_CANNOT_BE_REMOVED](../11-api/endpoints/identity.md)) | Not bypassable; this is where a rule depends on *data*, not just role |
| **Database — RLS, step 7** | Tenant/store scoping, independent of whether the API got steps 4–6 right | Not bypassable even by the API's own service-role connection, per [ADR-0004](../adr/ADR-0004-shared-schema-multi-tenancy.md) |

This is the concrete shape of this phase's "defence in depth" rule: **a bug in step 5 (the API
forgetting a permission check on a new endpoint) is still caught by step 7** for anything
tenant/store-scoped, though not for a same-tenant role violation, which is why steps 4–6 exist as
their own layer rather than relying on RLS for role logic RLS was never designed to express.

## 4. Why role, not a fine-grained permission list

[permission-matrix.md](../05-personas/permission-matrix.md) already resolved this: 3 roles × 16
capabilities is a fixed, small, fully-enumerated matrix — not a general-purpose permission system
with roles composed from individual grants. Building a more flexible RBAC/ABAC system now would be
speculative generality for a product whose entire V1 role set is three fixed, well-understood roles;
if V4's multi-outlet or franchise scenarios need finer-grained permissions, that is a redesign
input for whenever that scope is actually reached, not a V1 concern.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | 7-step fail-closed evaluation order; 4-layer enforcement table with explicit bypassability per layer; rationale for flat roles over general RBAC. |
