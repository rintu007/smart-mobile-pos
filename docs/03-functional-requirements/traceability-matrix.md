# Traceability Matrix

> **Status:** 🔵 In review
> **Phase:** 03 — Functional Requirements
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Business Analyst / CTO
> **Approved by:** _pending_

The consolidated `BR → FR → US` view required by this phase's charter. Regulatory requirements
(`RR-NNN`, from [Phase 02](../02-business-requirements/regulatory-requirements.md)) are noted
inline where an FR traces to one directly, alongside its `BR`.

**Reading this document:** Table 1 is the mandatory direction — every `BR` must have at least one
`FR`, checked against [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)'s V1
module list. Table 2 shows where a user story exists on top of that — not every `FR` has one, and
[user-stories.md](user-stories.md) explains why that's by design, not a gap.

---

## Table 1 — BR → FR (complete; all 54 business requirements)

| BR | Functional Requirements |
| --- | --- |
| BR-001 | FR-001, FR-002, FR-003, FR-004, FR-005, FR-006, FR-039 |
| BR-002 | FR-002, FR-007, FR-008, FR-056, FR-075 |
| BR-003 | FR-005, FR-009, FR-023, FR-042, FR-047 |
| BR-004 | FR-010, FR-011, FR-012, FR-053, FR-061, FR-081, FR-084 |
| BR-005 | FR-013, FR-014 |
| BR-006 | FR-003, FR-015, FR-016 |
| BR-007 | FR-017 |
| BR-008 | FR-018, FR-019, FR-066 |
| BR-009 | FR-019, FR-020, FR-021, FR-030 |
| BR-010 | FR-005, FR-022, FR-023 |
| BR-011 | FR-005, FR-024 |
| BR-012 | FR-025, FR-034 |
| BR-013 | FR-026, FR-027 |
| BR-014 | FR-028 |
| BR-015 | FR-029, FR-030 |
| BR-016 | FR-031 |
| BR-017 | FR-004, FR-032, FR-033, FR-034 |
| BR-018 | FR-035, FR-036 |
| BR-019 | FR-037, FR-038 |
| BR-020 | FR-004, FR-039 |
| BR-021 | FR-040, FR-041 |
| BR-022 | FR-042 |
| BR-023 | FR-043, FR-044 |
| BR-024 | FR-045, FR-048, FR-074 |
| BR-025 | FR-027, FR-041, FR-044, FR-046, FR-064, FR-072 |
| BR-026 | FR-047, FR-048, FR-082 |
| BR-027 | FR-049, FR-050 |
| BR-028 | FR-051 |
| BR-029 | FR-050, FR-052 |
| BR-030 | FR-053, FR-054 |
| BR-031 | FR-008, FR-055, FR-056 |
| BR-032 | FR-057, FR-058 |
| BR-033 | FR-005, FR-059 |
| BR-034 | FR-060 |
| BR-035 | FR-061 |
| BR-036 | FR-062 |
| BR-037 | FR-063, FR-064, FR-065 |
| BR-038 | FR-066 |
| BR-039 | FR-067 |
| BR-040 | FR-068, FR-069 |
| BR-041 | FR-070 |
| BR-042 | FR-071 |
| BR-043 | FR-072 |
| BR-044 | FR-073 |
| BR-045 | FR-074 |
| BR-046 | FR-075, FR-076 |
| BR-047 | FR-016 |
| BR-048 | FR-077 |
| BR-049 | FR-078 |
| BR-050 | FR-079, FR-080 |
| BR-051 | FR-011, FR-081 |
| BR-052 | FR-082 |
| BR-053 | FR-083 |
| BR-054 | FR-084 |

**Coverage check: 54/54 business requirements have at least one functional requirement. Zero `FR`s
are unattached to a `BR`** — cross-verified against [functional-requirements.md](functional-requirements.md),
where every FR's "Traces to" column names at least one BR.

## Table 2 — Regulatory requirements woven into functional requirements

| RR (from Phase 02) | Functional Requirements |
| --- | --- |
| RR-001 (tax registration status) | FR-007, FR-056 |
| RR-002 (offline invoice numbering) | FR-058 |
| RR-003 (tax invoice mandatory fields) | FR-033, FR-055, FR-078 |
| RR-004 (per-line tax rounding) | FR-076 |
| RR-007 (payment data deferred to gateway) | Not yet applicable — first exercised in V3 |
| RR-008 (default DB region) | Not yet applicable — Phase 12 decision |

## Table 3 — FR → US (where a story exists)

Not every FR has a user story — see [user-stories.md](user-stories.md#what-is-intentionally-not-covered)
for why that's intentional.

| US | Functional Requirements |
| --- | --- |
| US-001 | FR-001, FR-002, FR-003, FR-004, FR-005, FR-006 |
| US-002 | FR-007 |
| US-003 | FR-022, FR-024 |
| US-004 | FR-025 |
| US-005 | FR-026, FR-027 |
| US-006 | FR-009, FR-042, FR-059 |
| US-007 | FR-048, FR-082 |
| US-008 | FR-029 |
| US-009 | FR-035, FR-037 |
| US-010 | FR-039 |
| US-011 | FR-043 |
| US-012 | FR-045, FR-074 |
| US-013 | FR-050, FR-062 |
| US-014 | FR-051 |
| US-015 | FR-055 |
| US-016 | FR-056 |
| US-017 | FR-059 |
| US-018 | FR-060, FR-061 |
| US-019 | FR-062 |
| US-020 | FR-066 |
| US-021 | FR-067, FR-068, FR-069 |
| US-022 | FR-070 |
| US-023 | FR-071, FR-072 |
| US-024 | FR-073 |
| US-025 | FR-075, FR-076 |
| US-026 | FR-077 |
| US-027 | FR-083 |
| US-028 | FR-084 |

**FRs with no user story (by design — architectural/system constraints, not persona-facing wants):**
FR-008, FR-010, FR-011, FR-012, FR-013, FR-014, FR-015, FR-016, FR-017, FR-018, FR-019, FR-020,
FR-021, FR-023, FR-028, FR-030, FR-031, FR-032, FR-033, FR-034, FR-036, FR-038, FR-040, FR-041,
FR-044, FR-046, FR-047, FR-049, FR-052, FR-053, FR-054, FR-057, FR-058, FR-063, FR-064, FR-065,
FR-078, FR-079, FR-080, FR-081.

## Module coverage cross-check

Every V1 module in [modules/README.md](../modules/README.md) has requirements at every layer:

| V1 Module | BR range | FR range | Has US? |
| --- | --- | --- | --- |
| Authentication | BR-005 | FR-013–014 | — (architectural) |
| Company & Store Setup | BR-001, 002, 006, 007 | FR-001–008, 015–017 | US-001, US-002 |
| Roles & Permissions | BR-008, 015, 038 | FR-018, 029, 066 | US-008, US-020 |
| Audit Log | BR-009 | FR-019–021 | — (architectural) |
| Categories | BR-018 | FR-035–036 | US-009 |
| Units | BR-019 | FR-037–038 | US-009 |
| Products | BR-017, 020 | FR-004, 032–034, 039 | US-010 |
| Inventory — Stock Ledger | BR-021–026 | FR-040–048 | US-007, US-011, US-012 |
| Customers (basic) | BR-027–029 | FR-049–052 | US-013, US-014 |
| POS | BR-003, 010–016 | FR-005, 009, 022–031 | US-003–US-006, US-008 |
| Sales & Invoices | BR-004, 030–032 | FR-010–012, 053–058 | US-015, US-016 |
| Receipt & Printing | BR-033–035 | FR-059–061 | US-017, US-018 |
| Returns & Refund | BR-036–038 | FR-062–066 | US-019, US-020 |
| Cash Drawer / Day Close | BR-039–041 | FR-067–070 | US-021, US-022 |
| Reports | BR-042–045 | FR-071–074 | US-023, US-024 |
| Settings | BR-046–049 | FR-075–078 | US-025, US-026 |
| Offline Sync Engine | BR-003, 004, 050–054 | FR-079–084 | US-027, US-028 |

No V1 module is without a requirement at every layer, and no requirement is orphaned from a module.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial matrix: 54/54 BRs traced to FRs, RR cross-references, FR→US mapping, and per-module coverage check. |
