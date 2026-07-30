# Incident Response

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** Security Engineer / CTO
> **Approved by:** _pending_

Detection, containment, notification obligations, and recovery — a small team's realistic incident
process, built from the controls already specified in this phase rather than a new apparatus.

---

## 1. Detection

At V1 scale, detection relies on the free-tier logging and alerting Supabase and Vercel already
provide (request logs, auth logs, database logs) — a dedicated security-monitoring product is not
justified at this scale and would violate the free/open-source-first constraint without a
proportionate benefit. The specific, concrete signals worth alerting on, once Phase 18 wires up
actual alerting: a spike in `RATE_LIMITED` responses (§ [rate-limiting.md](../11-api/rate-limiting.md)),
a spike in `PERMISSION_DENIED`/`DEVICE_REVOKED` responses (credential-stuffing or a revoked device
still attempting access), and any `IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD` occurrence
([error-catalogue.md](../11-api/error-catalogue.md)) — a genuine client bug or an active attempt to
tamper with an in-flight operation, not a normal condition.

## 2. Containment

The tools to contain an incident already exist elsewhere in this phase, reused directly rather than
duplicated:

| Incident | Containment action |
| --- | --- |
| A specific device compromised (lost, stolen, suspected malware) | Revoke the device — [authentication.md §5](../11-api/authentication.md#5-revocation-flow); effective on the API within one request round-trip, per [identity-and-sessions.md §5](identity-and-sessions.md#5-revocation--the-security-guarantee-restated-precisely) |
| A specific account compromised (credential leak) | Revoke every device for that user (iterate the same mechanism); force a password reset via Supabase Auth |
| A secret (service-role key, connection string) suspected leaked | Immediate out-of-cycle rotation, per [secrets-management.md §4](secrets-management.md#4-rotation) |
| An RLS policy defect discovered (a TB-2 leak) | The affected policy is corrected and the migration re-run through the same CI gate described in [tenant-isolation.md §3](tenant-isolation.md#3-ci-enforcement--not-a-one-time-proof) — this is the scenario that gate exists to prevent from ever reaching production undetected in the first place |

## 3. Notification obligations

Under the same **provisional** DPDPA assumption as [privacy.md §2](privacy.md#2-lawful-basis--provisional-tied-to-the-same-od-01-assumption-as-everything-else-tax-adjacent),
a personal-data breach carries a notification obligation to affected users and, depending on scale
and severity, a regulator. This is stated here as a known obligation category, **not** as specific,
reliable legal guidance on thresholds or timelines — that determination is part of the same pending
legal/privacy review already tracked as a standing cross-phase item, not invented here. What this
document fixes now, independent of that review: **the technical capability to determine which
customers/records were actually affected by a given incident**, since `audit_log`'s
`(tenant_id, entity_type, entity_id)` index ([schema-server.md](../07-database/schema-server.md))
already lets an incident's blast radius be reconstructed precisely — notification cannot happen
responsibly without first knowing exactly who was affected, and that capability already exists.

## 4. Recovery

Restoration relies on Supabase's backup capability. **This is where [OD-02](../01-vision/open-decisions.md)'s
still-open budget ceiling becomes concretely relevant, not abstractly**: Supabase's free tier
provides limited-retention daily backups; point-in-time recovery (restoring to any specific moment,
not just the last daily snapshot) is a paid-tier capability. For a financial application, the gap
between "lose up to a day's transactions" and "restore to the minute" is a real, costed decision —
this document flags backup/PITR retention as a concrete, specific input to the monthly budget figure
[OD-02](../01-vision/open-decisions.md) is still waiting on, rather than leaving "adequate backups"
as an unstated assumption.

## 5. What this document does not build

A written, rehearsed incident-response runbook with named on-call responsibilities is a Phase 18
operational deliverable once there is a team beyond the founder to assign it to — this document
fixes the technical mechanisms recovery and containment depend on; the human process wrapped around
them is sized to the team that exists at the time, not invented in the abstract now.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Detection signals identified from existing error codes; containment mapped to already-specified revocation/rotation mechanisms; notification obligation flagged provisionally; backup/PITR gap tied concretely to OD-02's open budget question. |
