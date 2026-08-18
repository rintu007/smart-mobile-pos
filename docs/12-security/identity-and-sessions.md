# Identity and Sessions

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.1.1
> **Last updated:** 2026-08-19
> **Owner:** Security Engineer / CTO
> **Approved by:** _pending_

The security-analysis view of the token mechanism [authentication.md](../11-api/authentication.md)
already specified — this document does not re-derive that design, it states the specific properties
that make it sound and the failure modes that were deliberately considered and closed.

---

## 1. Token lifetime — the concrete numbers and why

| Token | Lifetime | Reason |
| --- | --- | --- |
| Access token | 60 minutes | Short enough to bound the TB-2 Realtime exposure window after a device revocation ([authentication.md §4](../11-api/authentication.md#4-device-binding-and-revocation--checked-on-every-request-not-only-at-token-mint)) to at most an hour; long enough that a Cashier mid-shift isn't repeatedly interrupted by expiry under normal connectivity. |
| Refresh token | Supabase default (weeks), rotated on every use | A POS device is often signed in for an entire shift or longer without the user re-authenticating — forcing frequent re-login on a shared, shop-floor device (per [device-and-context.md](../05-personas/device-and-context.md)) would be actively hostile to the Cashier persona's veto power. |

## 2. Signing — deferred to Phase 18 verification, by design

The JWT signing algorithm and key management are entirely Supabase Auth's responsibility, not a
custom implementation this project maintains. Consistent with this documentation set's standing
practice of not committing to unverified tool specifics (see [ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md)'s
UUID-tooling precedent), the exact current signing configuration (symmetric vs. asymmetric, key
rotation cadence) is confirmed against Supabase's documentation at Phase 18 — the architectural
commitment made now is simply: **we verify, we never mint our own competing token**, and the
Custom Access Token Hook only ever *adds* a claim to Supabase's own token, never replaces it.

## 3. Refresh-token reuse detection

A rotated-out refresh token that is presented again (the signature of a token having been stolen and
used by both the legitimate device and an attacker) is rejected by Supabase's own reuse-detection
behaviour, and — per this phase's fail-closed rule — treated as a signal to invalidate the entire
session family, not merely the one reuse attempt. The legitimate device is forced to re-authenticate;
this is a deliberate inconvenience traded against the alternative (an attacker's stolen token
continuing to work silently).

## 4. Multi-device — deliberately supported, not an edge case

Per [device-and-context.md](../05-personas/device-and-context.md)'s finding that a device is often
**shared across shifts/staff**, this product does not restrict a user to one active session. Each
login creates its own `devices` row ([schema-server.md](../07-database/schema-server.md)) and its
own independent token pair; revoking one device's session (§5 below) never affects another. This is
a deliberate design stance, not a limitation left unaddressed: a security model that assumed
one-device-per-user would be actively wrong for this product's real usage pattern.

## 5. Revocation — the security guarantee, restated precisely

Per this phase's exit criterion, **a lost or stolen device can have its sessions revoked
server-side.** The precise guarantee: within one API request round-trip after an Owner revokes a
device ([authentication.md §5](../11-api/authentication.md#5-revocation-flow)), that device's next
API call is rejected — this is a hard, immediate guarantee, not "eventually." The **Realtime**
guarantee is weaker and stated as such, not glossed over: a revoked device's existing Realtime
subscription remains authorised until its current access token naturally expires (≤60 minutes, per
§1) — accepted because closing this gap would require an API-fronted Realtime layer, which
[ADR-0001](../adr/ADR-0001-hybrid-api-and-direct-realtime-access.md) already rejected as
reimplementing a solved problem badly.

## 6. Failed-login lockout

Per [rate-limiting.md §1](../11-api/rate-limiting.md#1-limits-by-endpoint-class), repeated failed
sign-in attempts are throttled per-account and per-IP. This project does not implement a separate,
harsher **account lockout** (temporarily disabling an account after N failures) beyond that rate
limit — a lockout mechanism is itself a denial-of-service vector against a legitimate Cashier if an
attacker deliberately fails logins to lock a real account out during business hours. Rate limiting
achieves the brute-force resistance goal without introducing that new risk.

**Correction, found Sprint 43 (backlog.md M4 item 8, [owasp-checklist.md](owasp-checklist.md) A07):**
"rate limiting achieves" is a design claim, not a present fact — no rate-limiting code exists
anywhere in `apps/web/src` (confirmed by grep, and by the absence of any rate-limit package in
`package.json`). This section's design is sound and unchanged; it has simply never been built. Real,
standalone scope for a future sprint, not fixed in this pass.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Token lifetimes justified, reuse detection and multi-device stance stated, revocation guarantee precisely scoped (hard for API, bounded-not-instant for Realtime), lockout-vs-rate-limit trade-off decided. |
| 0.1.1 | 2026-08-19 | §6 corrected (Sprint 43, backlog.md M4 item 8): rate limiting is a design claim, not yet implemented anywhere in code — flagged as a real gap, not fixed this pass. |
