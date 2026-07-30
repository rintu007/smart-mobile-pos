# Security Test Plan

> **Status:** 🔵 In review
> **Phase:** 14 — Testing Strategy
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** QA Lead / Security Engineer
> **Approved by:** _pending_

Cross-tenant isolation, authorisation, injection, and secret leakage — the execution plan for
[Phase 12](../12-security/README.md)'s already-specified controls, following the same
pointer-not-duplicate pattern as [offline-test-suite.md](offline-test-suite.md).

---

## 1. Cross-tenant isolation

**Content:** [tenant-isolation.md §2](../12-security/tenant-isolation.md#2-what-every-table-means-precisely-restated-as-a-checklist)'s
22-table checklist, plus the Realtime-channel extension in
[tenant-isolation.md §4](../12-security/tenant-isolation.md#4-extending-the-cross-tenant-proof-to-realtime).
**CI placement:** every migration touching a tenant-owned table, blocking — restated as this phase's
own exit criterion, not a new requirement. **Owner:** the same automated suite; this document adds
no new test cases, only confirms it is wired as a hard release/merge gate.

## 2. Authorisation

**Content:** [authorisation-model.md §2](../12-security/authorisation-model.md#2-evaluation-order--every-request-in-this-sequence-fail-closed-at-every-step)'s
7-step evaluation order, tested at each step independently (a test asserting step 4's failure denies
access even if steps 1–3 pass; a test asserting step 7's RLS layer denies access even if a
hypothetical bug made step 5 pass incorrectly) — this is what makes "defence in depth" a tested
property rather than an architectural aspiration. Additionally: [permission-matrix.md](../05-personas/permission-matrix.md)'s
full 16-capability × 3-role matrix, every one of the 48 cells asserted individually
([test-strategy.md §1](test-strategy.md#1-business-rule-traceability--the-exit-criterion-made-checkable)'s
DR-019/020/021 row) — not sampled, because a permission matrix is exactly the kind of artefact where
"we tested the important ones" quietly excludes the one cell that mattered.

## 3. Injection

**Content:** the structural claims in [input-validation.md](../12-security/input-validation.md) are
verified, not merely asserted by design:
- **SQL injection:** a CI lint rule fails the build on any use of `$queryRawUnsafe` or raw string-
  concatenated SQL, per [input-validation.md §3](../12-security/input-validation.md#3-sql-injection-is-a-structural-non-issue-not-a-discipline-one) —
  tested by including one deliberately-bad fixture file in the lint-rule's own test suite that must
  trigger the failure, so the rule's absence-of-findings on real code is trusted because the rule is
  proven to fire on a known-bad input, not just because it never complained.
- **XSS:** for the (currently minimal) web admin surface, a test asserting no `dangerouslySetInnerHTML`
  usage exists outside an explicitly allow-listed, reviewed exception file — an allow-list of zero
  entries today, per [input-validation.md §6](../12-security/input-validation.md#6-web-admin--xss-v2-specified-now-since-the-pattern-is-fixed-by-the-framework-choice).
- **Path traversal:** a test asserting every Storage-bound object key used anywhere in the codebase
  is server-generated (a UUID pattern), never derived from a request parameter — a static-analysis
  check, not a runtime fuzz test, since the guarantee here is structural per
  [input-validation.md §5](../12-security/input-validation.md#5-file-uploads--path-traversal-is-structurally-avoided-not-filtered).

## 4. Secret leakage

**Content:** both mechanisms from [secrets-management.md §3](../12-security/secrets-management.md#3-the-build-time-check--the-exit-criterions-actual-mechanism),
run as actual CI jobs: the dependency-cruiser import-boundary rule (client code may never import
`core/db`) and the built-bundle content scan (known secret values and high-entropy server-only
variable-name patterns). **Both run on every build**, per
[secrets-management.md](../12-security/secrets-management.md)'s own requirement, restated here as
this phase's execution commitment — not release-gated only, since a leak introduced on a feature
branch should be caught in that branch's CI.

## 5. What this document adds beyond Phase 12

Phase 12 specified every control and its rationale. This document's only additions are: (a) explicit
CI placement/timing for each (§§1–4 tables), and (b) the "prove the checker itself works" discipline
in §3's SQL-injection rule — a genuinely new instrument, not present in Phase 12, added because a
lint rule that has never been tested against a known-bad case is a false sense of security identical
in kind to the untested assumptions this entire documentation set exists to avoid.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Execution plan for Phase 12's four control areas; added the fixture-based self-test for the SQL-injection lint rule as this phase's one genuinely new instrument. |
