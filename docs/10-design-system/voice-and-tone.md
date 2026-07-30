# Voice and Tone

> **Status:** 🔵 In review
> **Phase:** 10 — Design System
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** UI-UX Lead
> **Approved by:** _pending_

The writing standard behind every error message and empty state referenced throughout this phase —
[components.md](components.md), [patterns.md](patterns.md), and
[state-presentation.md](state-presentation.md) all point here rather than each inventing copy
rules independently.

---

## 1. Grounding: who is reading this, mid-shift

Per [accessibility-profiles.md](../05-personas/accessibility-profiles.md)'s literacy-range finding
and [device-and-context.md](../05-personas/device-and-context.md)'s queue-pressure finding, the
reader is often not reading closely — a Cashier under time pressure with a customer watching.
Copy is written for that reader, not for a relaxed reader with time to parse a careful sentence.

## 2. Rules

| Rule | Bad example | Good example | Why |
| --- | --- | --- | --- |
| **State the concrete problem, not the abstract failure** | "Operation failed" | "Printer not connected" | Matches [accessibility-profiles.md](../05-personas/accessibility-profiles.md)'s literacy finding directly — concrete, recognisable nouns beat abstract technical framing. |
| **Never show a raw error code, ID, or stack trace** | "Error 500: unexpected token" | (no code shown at all — logged internally per [audit-model.md](../07-database/audit-model.md)) | A code helps nobody standing at a till; it belongs in a log, not a message. |
| **Name the consequence in a destructive confirmation, in the shop's own terms** | "Are you sure?" | "Remove 3 items and discard this sale?" | Already this phase's founding rule ([README.md](README.md)); restated here as the copy-writing instance of it. |
| **Never blame the user** | "You entered an invalid amount" | "Enter an amount of at least ₹68.00" | States what to do next, not what was done wrong — a small but consistent difference in a system used for eight hours a day. |
| **Empty states are an invitation, not a dead end** | "No products" | "No products yet — add your first one" | Per [patterns.md §4](patterns.md#4-empty-state) — a genuinely-empty state always pairs with the action that resolves it. |
| **Offline copy is calm, never alarming** | "⚠ You are offline! Data may be lost!" | "Working offline — will sync when you're back online" | Per [state-presentation.md §4](state-presentation.md#4-offline) — offline is the expected condition, not a fault; the copy must not contradict the visual calm the design already commits to. |
| **Use the shop's own vocabulary, not internal system terms** | "Transaction voided" | "Sale removed" / (in practice: sales cannot be voided at all, per [permission-matrix.md](../05-personas/permission-matrix.md) — only returned) | Consistency with [GLOSSARY.md](../GLOSSARY.md)'s established terms — "sale," not "transaction"; "return," not "reversal." |
| **Numbers are never rounded away in copy** | "You saved some money" | "You saved ₹3.40" | A vague quantity undermines trust in a financial application faster than almost anything else. |

## 3. Length

- Error messages: one sentence, ideally under 12 words.
- Empty-state messages: one short sentence plus, where applicable, one action label — not a
  paragraph explaining the feature.
- Destructive-confirmation messages: exactly what will be lost, in as few words as state it
  precisely — "Remove 3 items and discard this sale?" not a longer justification of why the
  confirmation exists.

## 4. Localisation readiness

Per [accessibility-profiles.md](../05-personas/accessibility-profiles.md)'s language finding, no
specific additional language is committed for V1 (blocked on [OD-01](../01-vision/open-decisions.md)),
but every string this document governs is written as an externalised, translatable string from
first implementation — a short, literal, idiom-free sentence (per §2/§3 above) also happens to be
far easier to translate accurately later than a clever or culturally specific phrase would be. This
is a case where the accessibility-driven writing style and the localisation-readiness requirement
reinforce each other rather than trading off.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial voice-and-tone rules with bad/good examples; length limits; localisation-readiness note tying back to the OD-01 language gap. |
