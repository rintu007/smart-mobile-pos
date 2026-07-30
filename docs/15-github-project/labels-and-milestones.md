# Labels and Milestones

> **Status:** 🔵 In review
> **Phase:** 15 — GitHub Project
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** CTO
> **Approved by:** _pending_

Label taxonomy and milestone structure — the mechanism; the actual milestone dates are
[16-milestones](../16-milestones/README.md)'s job, one phase away, and are not invented here.

---

## 1. Label taxonomy

One label per axis, prefixed so they group visibly in GitHub's label list — never a flat,
unprefixed pile of labels that becomes unsearchable past a dozen entries.

| Prefix | Values | Mirrors |
| --- | --- | --- |
| `type:` | `module`, `feature`, `defect`, `adr-proposal`, `security` | [project-board.md §2](project-board.md#2-item-types)'s item types |
| `module:` | One per V1 module (`till`, `catalogue`, `inventory`, `customers`, `sales`, `returns`, `settings`, ... per [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)) | [backend-structure.md §3](../08-folder-structure/backend-structure.md#3-module-to-table-mapping)'s module list |
| `priority:` | `P0` (blocks release), `P1`, `P2` | [project-board.md §3](project-board.md#3-fields) |
| `risk:` | `R-01` … `R-10` | [risks-constraints-assumptions.md](../01-vision/risks-constraints-assumptions.md)'s register — applied only when an item genuinely touches a named risk, not decorative |
| `release:` | `v1`, `v2`, `v3`, `v4` | [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md) |
| `status:` | `blocked`, `needs-decision` | Surfaces items waiting on an [open-decisions.md](../01-vision/open-decisions.md)-style call, searchable across the whole repo, not just the board |

**No `good-first-issue`/`help-wanted` labels yet** — meaningful once there is a contributor base
beyond the founding team; adding them now would be decoration with no audience, the same reasoning
this documentation set has applied to every other premature-generality decision.

## 2. Milestone structure — the naming convention, not the dates

Milestones are named `V1.0`, `V1.1`, ... matching [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)'s
slices, **not** sprint numbers — a milestone represents a shippable increment of product scope, and
[17-sprints](../17-sprints/README.md)'s sprint cadence is a separate, internal planning rhythm that
maps *into* milestones, not the reverse (several sprints can and will land inside one milestone).
Each milestone's description field links back to the specific scope-and-release-slices.md section
it corresponds to, so "what does V1.0 actually contain" is always one click from the milestone
itself, never a separate document someone has to remember to cross-reference.

**Due dates are deliberately not set in this document** — per [16-milestones](../16-milestones/README.md)'s
own charter and the still-open [OD-06](../01-vision/open-decisions.md) capacity question, a date
fabricated here with no real capacity input behind it would be exactly the kind of schedule this
documentation set's own standing practice refuses to invent ahead of the information needed to make
it real.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Six-axis label taxonomy; milestone naming convention fixed to release slices, not sprints; due dates deliberately deferred to Phase 16 pending OD-06. |
