# Environments

> **Status:** 🔵 In review
> **Phase:** 15 — GitHub Project
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** DevOps Engineer / CTO
> **Approved by:** _pending_

Local, development, staging, production — and what differs between them.

---

## 1. The four environments

| Environment | Supabase project | Vercel deployment | Who uses it |
| --- | --- | --- | --- |
| Local | A contributor's own free Supabase project, or the Supabase local CLI/Docker emulator | `next dev`, run locally | Individual development |
| Development | One shared free-tier Supabase project | Vercel's automatic per-PR preview deployments | Every open pull request gets its own isolated preview against this shared backend |
| Staging | A second free-tier Supabase project, kept as close to production configuration as free tiers allow | A dedicated Vercel deployment tracking a `release/**` branch | Release-candidate testing ([ci-workflows.md §3](ci-workflows.md#3-release-candidateyml--manually-triggered-or-on-a-release-branch-push)), the rollback rehearsal ([cd-workflows.md §5](cd-workflows.md#5-the-rehearsal--an-honest-gap-not-skipped)) |
| Production | The paid production tier ([OD-02](../01-vision/open-decisions.md), Option B — [ADR-0002](../adr/ADR-0002-hosting-posture-for-commercial-launch.md)) | Vercel production deployment tracking `main` | Real shops |

## 2. What differs, concretely

- **Secrets:** every environment has its own independent set — a development secret is never reused
  in staging or production, per [secrets-management.md §4](../12-security/secrets-management.md#4-rotation)'s
  rotation stance and [release-checklist.md §3](../14-testing/release-checklist.md#3-commercial-launch-ready-checklist--pilot-ready-plus)'s
  explicit "never reusing development/pilot secrets" gate.
- **Data:** development and staging are seeded with the fictional data in
  [seed-data.md](../07-database/seed-data.md) (Grocery/Mobile Shop worked examples) — never real
  shop data. Production holds real data exclusively and is never used as a source to refresh a lower
  environment without deliberate anonymisation, consistent with [privacy.md](../12-security/privacy.md)'s
  stance on personal data handling.
- **Connection pooling:** only staging and production run the Supavisor transaction-mode pooling
  configuration ([rate-limiting.md §3](../11-api/rate-limiting.md#3-connection-pooling--the-r-07-mitigation-load-tested-before-ga))
  under real load-test conditions — local/development traffic is too low-volume for pooling
  behaviour to be meaningfully exercised.
- **Backups:** development/staging rely on free-tier daily backups; production's backup/PITR tier is
  whatever [incident-response.md §4](../12-security/incident-response.md#4-recovery)'s still-open
  OD-02 budget decision lands on — this document does not duplicate that open item, only points at
  it.

## 3. The cost this document surfaces, concretely, for OD-02

Running a **second** always-on Supabase project for staging is itself a real, if usually small,
cost once free-tier project-count limits are considered — this is another concrete line item for
the still-open [OD-02](../01-vision/open-decisions.md) budget-ceiling question, alongside the
backup/PITR tier already flagged in [incident-response.md §4](../12-security/incident-response.md#4-recovery)
and the load-testing infrastructure flagged in [rate-limiting.md §3](../11-api/rate-limiting.md#3-connection-pooling--the-r-07-mitigation-load-tested-before-ga)
— named here so the eventual budget conversation has a complete list of concrete inputs rather than
discovering pieces of it one phase at a time.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Four environments specified with concrete differences (secrets, data, pooling, backups); staging's own Supabase-project cost added as a named OD-02 input. |
