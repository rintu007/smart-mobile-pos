# Issue Templates

> **Status:** 🔵 In review
> **Phase:** 15 — GitHub Project
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** CTO
> **Approved by:** _pending_

The five templates matching [project-board.md §2](project-board.md#2-item-types)'s item types,
specified as GitHub Issue Forms (YAML, native to GitHub — free, no third-party app) so each type
asks for exactly what it needs, structurally, rather than relying on a free-text body someone might
under-fill.

---

## 1. Module specification (`module.yml`)

```yaml
name: Module specification
description: A new business module entering Phase 18 implementation
labels: ["type:module"]
body:
  - type: input
    id: module-name
    attributes: { label: Module name }
    validations: { required: true }
  - type: input
    id: spec-path
    attributes: { label: Path to modules/<module>/ specification, description: "Must be 🟢 Approved before this issue is created — see definition-of-done.md" }
    validations: { required: true }
  - type: checkboxes
    id: dod-categories
    attributes:
      label: Definition of Done categories this module must satisfy
      options:
        - { label: Specification }
        - { label: Data }
        - { label: API }
        - { label: Mobile }
        - { label: Security }
        - { label: Tests }
        - { label: Documentation }
        - { label: Product }
```

## 2. Feature (`feature.yml`)

A scoped subset of a module — one endpoint, one screen. Asks for the module it belongs to, the
requirement IDs it satisfies (`FR-NNN`/`BR-NNN`), and whether it's offline-capable, mirroring the
same fields every [11-api/endpoints/](../11-api/endpoints/README.md) document already states per
endpoint, so a Feature issue is never asking a question the design phases haven't already answered.

## 3. Defect (`defect.yml`)

```yaml
name: Defect
description: A found, reproducible bug
labels: ["type:defect"]
body:
  - type: textarea
    id: repro
    attributes: { label: Steps to reproduce }
    validations: { required: true }
  - type: textarea
    id: expected-vs-actual
    attributes: { label: Expected behaviour vs. actual behaviour }
    validations: { required: true }
  - type: checkboxes
    id: regression-test
    attributes:
      label: Regression test
      options:
        - { label: "A regression test covering this defect exists and is linked below (required before this issue can move to Done, per this phase's Definition-of-Done discipline)" }
  - type: input
    id: regression-test-link
    attributes: { label: Link to the regression test }
```

## 4. ADR proposal (`adr-proposal.yml`)

Mirrors [adr/adr-template.md](../adr/adr-template.md)'s own structure directly — context, options
considered, recommendation — so a proposal raised as a GitHub issue and an eventual accepted ADR
document never diverge in shape; the issue is filled out, discussed, and once accepted, its content
becomes the numbered ADR file, not rewritten from scratch.

## 5. Security finding (`security-finding.yml`)

```yaml
name: Security finding
description: A vulnerability or security-relevant defect — per Phase 12, blocks release
labels: ["type:security", "priority:P0"]
body:
  - type: dropdown
    id: severity
    attributes:
      label: Severity
      options: [Critical, High, Medium, Low]
    validations: { required: true }
  - type: textarea
    id: description
    attributes: { label: What is the finding, and what is the realistic impact if unaddressed? }
    validations: { required: true }
  - type: checkboxes
    id: threat-model-update
    attributes:
      label: Threat model
      options:
        - { label: "docs/12-security/threat-model.md is updated to reflect this finding and its mitigation, if it represents a boundary/category not already covered" }
```

**Automatically labelled `priority:P0`** — per [Phase 12](../12-security/README.md)'s standing rule
that security findings block release with no exception, this label assignment is not left to
whoever triages the issue to remember.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Five GitHub Issue Forms specified, each structurally asking only what its item type needs; security findings auto-labelled P0. |
