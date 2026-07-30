# ADR-0000 — Adopt Architecture Decision Records

> **Status:** 🟢 Accepted
> **Date:** 2026-07-28
> **Phase:** 00 — Governance
> **Deciders:** CTO
> **Supersedes:** _none_

---

## Context

SmartPOS X is a commercial product intended to run real businesses' money and stock. It will be
built over a long period by a small team, with long gaps between a decision being made and its
consequences being felt. Decisions such as the stock model, the tenancy model and the offline
conflict strategy are effectively irreversible once customer data exists.

Without a record, three things happen — reliably, in every project of this shape:

1. Decisions are re-argued, because nobody remembers the original reasoning.
2. Decisions are accidentally reversed by a well-meaning refactor that "simplifies" something load-bearing.
3. The reasoning lives only in the head of whoever made it, and leaves when they do.

## Decision drivers

- Long project horizon with a small team.
- Several decisions that are irreversible after the first paying customer.
- Documentation is declared the single source of truth; decisions are part of that truth.
- The record must be cheap enough to write that it actually gets written.

## Options considered

### Option A — Architecture Decision Records in the repository

Short Markdown files, one per decision, versioned alongside the code they constrain.

| Pros | Cons |
| --- | --- |
| Lives with the code; diffs and reviews like code | Requires discipline to write |
| Free, no tooling, no vendor | Can grow into an unnavigable pile without an index |
| Captures rejected options, which is the valuable part | |

### Option B — Decisions recorded in issue tracker discussions

| Pros | Cons |
| --- | --- |
| Zero extra effort | Buried in comment threads; unsearchable in practice |
| | Tied to a vendor; lost if the tracker changes |
| | No distinction between a passing remark and a binding decision |

### Option C — A single running `DECISIONS.md`

| Pros | Cons |
| --- | --- |
| One file to find | Merge conflicts on every parallel decision |
| | Encourages one-line entries with no context or rejected options |
| | No per-decision status; cannot mark one superseded |

## Decision

We will **adopt Architecture Decision Records** (Option A), stored in `docs/adr/`, one file per
decision, sequentially numbered, indexed in `docs/adr/README.md`.

An ADR is required when reversing the decision would need a data migration, an API version bump,
or a rewrite spanning more than one module.

ADRs are **immutable once accepted**. Change is expressed by writing a new ADR that supersedes the
old one. The historical record of what we believed and when is itself an asset — it is how we learn
whether our judgement is calibrated.

## Consequences

**Positive**
- Every significant decision has a discoverable rationale including its rejected alternatives.
- Onboarding cost drops sharply; a new engineer reads the register instead of interviewing people.
- Refactors that would violate a decision are caught in review against a citable document.

**Negative — accepted costs**
- Roughly 20–40 minutes of writing per significant decision.
- Requires judgement about what qualifies; the boundary will occasionally be got wrong. Erring
  towards writing one is cheaper than erring towards not.
- The register must be curated, or it becomes an archive nobody reads.

**Neutral**
- ADR numbers are permanent and never reused, so gaps may appear if a proposal is abandoned.

## Compliance

- Pull request review checklist asks: "does this change embody a decision that needs an ADR?"
- The ADR register in `docs/adr/README.md` is updated in the same pull request as any new ADR.
- The decision backlog in that register is reviewed at the start of every phase.

## Revisit when

The team exceeds roughly fifteen engineers and the flat numbered register becomes hard to navigate.
At that point ADRs would be grouped by domain, not abandoned.
