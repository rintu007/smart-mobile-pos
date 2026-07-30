# Patterns

> **Status:** 🔵 In review
> **Phase:** 10 — Design System
> **Version:** 0.1.1
> **Last updated:** 2026-07-31
> **Owner:** UI-UX Lead / Principal Flutter Engineer
> **Approved by:** _pending_

Recurring **compositions** of the components in [components.md](components.md) — a pattern is not
a new component, it's a named, reusable arrangement so that "a list with a search bar above it"
looks and behaves the same on the Catalogue screen as it does on the sales-history lookup screen,
rather than being redesigned independently each time.

---

## 1. List-with-search

**Composition:** a search text input (§2 of [components.md](components.md)) pinned to the top of
the screen, above a scrollable list of §4 list items. Used by Catalogue browse, sales-history
lookup, and the multi-held-cart resume list from
[navigation-model.md](../09-navigation/navigation-model.md#2-quick-actions-surfaced-directly-on-the-till-screen--not-buried-in-a-menu).

| Sub-state | Treatment |
| --- | --- |
| No query yet | Full list shown, most-recent or most-relevant ordering — never an empty screen waiting for input |
| Query, results found | Filtered list, matched text **not** visually highlighted (bolding matched substrings adds visual noise without proportionate benefit at POS reading speed — a deliberate omission) |
| Query, no results | The empty-state pattern (§4), with the literal query included in the message: "No products match 'expiy'" — lets the Cashier see their own possible typo |

## 2. Form

**Composition:** a vertical stack of §2 text inputs / §12 segmented controls, `space-md` between
fields, a single primary action (§1) fixed to the bottom of the screen (not requiring a scroll to
reach on any device in [device-and-context.md](../05-personas/device-and-context.md)'s target
band). Used by product-edit, settings, and customer-detail screens.

Validation is inline, per-field, on blur — never deferred to a single block of errors shown only
after the primary action is pressed. Under queue pressure or one-handed use, discovering all
mistakes at once after a failed submit costs more taps than catching each one as it happens.

## 3. Confirmation

**Composition:** the §9 dialog, triggered before any destructive or hard-to-reverse action (void
attempt paths are actually impossible per [permission-matrix.md](../05-personas/permission-matrix.md),
but discard-cart, delete-product, and remove-line-item all qualify). Always states the concrete
consequence, per [this phase's founding rule](README.md) — see the destructive-confirmation row in
[components.md §9](components.md#9-dialogs-confirmation).

## 4. Empty state

**Composition:** centred icon (Outlined style per [foundations.md §8](foundations.md#8-iconography)),
one-line message, optional single action. Three flavours, never conflated:

| Flavour | When | Message stance |
| --- | --- | --- |
| **Genuinely empty** | A brand-new shop's Catalogue before any product is added | Encouraging, action-forward: "No products yet — add your first one" with the action attached directly |
| **No results** | A search or filter that legitimately matches nothing | Neutral, states what was searched — see §1 |
| **Offline-stale, showing nothing** | No cached data exists yet for a screen that requires it | Distinct from both above — owned by [state-presentation.md](state-presentation.md), not this pattern, because it is a connectivity state, not a data state |

## 5. Bottom-sheet action

**Composition:** the §8 bottom sheet, opened from a single tap on a list item or a quick action,
containing a short vertical list of actions (each a full-width, 48 dp-minimum tap target with a
leading icon). Used for per-item actions (e.g. long-press a cart line for "Remove" / "Change
quantity" / "Apply item discount") — chosen over a dialog because it holds more than two or three
options without feeling cramped, and over a dedicated screen because the action list is genuinely
transient.

## 6. Permission-denied

**Composition:** not a blank screen and not a silent redirect. Per
[guards-and-redirects.md](../09-navigation/guards-and-redirects.md)'s permission guard, a route a
user's role cannot access shows: an icon, "You don't have access to this" (or the specific reason,
where one is useful — e.g. "Reports are visible to Managers and Owners"), and a single action
returning to Till. This pattern exists so implementation never improvises a bare `403`-style
response into the UI.

## 7. Numeric entry

**Composition:** the §3 numeric keypad, docked to the bottom half of the screen, with the running
value displayed large and in tabular figures directly above it, and the confirm action (§1) fixed
above the keypad. Used for cash tendered, discount amount, stock-adjustment quantity. The keypad
never covers the value it is producing — a persistent design flaw in cheaper POS apps this system
deliberately avoids.

## 8. Receipt preview

**Composition:** a scrollable, monospace-rendered preview matching the actual thermal output
(58 mm or 80 mm, per the shop's configured printer — see [receipt-design.md](receipt-design.md)),
shown before the physical print/share action, inside a bottom sheet (§8) with two actions: Print,
Share (PDF, via the OS share sheet). This lets a Cashier catch a wrong price or a missing item
before committing paper — cheap, thermal paper is not free, and reprints cost real money at scale.

---

## 9. Error card

**Composition:** the specific layout [components.md §5](components.md#5-cards)/[§8](components.md#8-bottom-sheet)
promise is "defined once in patterns.md, not improvised per screen" — this is that definition,
added here after the fact once it became clear it had been promised but never actually written
down. A centred icon (Outlined, `error`-coloured per [foundations.md §2](foundations.md#2-colour--one-seed-two-themes),
matching the general semantic-colour-plus-icon rule so this never relies on colour alone), a
one-line plain-language message ([voice-and-tone.md](voice-and-tone.md)'s standard — concrete,
never a raw code), and a single primary action button (§1 of [components.md](components.md)):
"Retry" for a transient failure, or a narrower, specific action where retry isn't the right verb
(e.g. "Go back"). Used inside a Card (§5 of [components.md](components.md), replacing that card's
normal content entirely, not overlaid on top of it) and inside a Bottom sheet (§8, same substitution
rule) — the same composition in both containers, per components.md's own cross-reference, so an
error never looks different depending on which container it happens to be rendered inside.

---

## 10. Proof — three complete screens composed from this system, nothing invented

Per this phase's exit criterion, the three screens below are each described entirely in terms of
already-defined tokens ([foundations.md](foundations.md)), components
([components.md](components.md)), and the patterns above. No new visual element appears.

### 9.1 Till — active sale

Full-screen cart ([navigation-model.md §3](../09-navigation/navigation-model.md#3-the-one-exception-the-active-sale-full-screen)):
app bar with Hold/Return/Day icons (§2 of navigation-model.md) → §4 list items for each cart line,
tabular-figure prices → §7 numeric entry pattern when adding a quantity → §9 confirmation dialog if
removing a line → §1 primary pill button ("Pay ₹—") fixed at the bottom, entering its loading state
on tap → §10 snackbar on success, or the dedicated error dialog (§9 of components.md) on failure.

### 9.2 Catalogue — product search and detail

§1 list-with-search pattern as the screen root → tapping a result opens a product detail using the
§5 Cards layout for the product summary → a §12 segmented control if the product has variants →
the §1 primary button to add to cart, which for an out-of-stock item is already in its disabled
state per [components.md §4](components.md#4-list-item--product--cart-line--sale-history-row).

### 9.3 Returns — process a return

§1 list-with-search to locate the original sale (per
[WF-012](../06-workflows/returns-workflows.md#wf-012--process-a-return)) → §4 list items,
multi-selectable, for the items being returned → §7 numeric-entry pattern if a partial quantity is
returned → §3 confirmation dialog stating the refund amount and method → §11 progress indicator if
the return requires Manager approval and is queued (per
[tap-count-audit.md](../09-navigation/tap-count-audit.md#back-office-workflows-managerowner-not-pos-comparable--no-1-tap-from-launch-requirement-applies))
→ §10 snackbar on completion.

Every element used above already has a full state definition in [components.md](components.md);
composing these three screens required zero new visual decisions — which is the point of this
exit criterion.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial 8 patterns; three-screen composition proof (§9) closes this phase's system-completeness exit criterion. |
| 0.1.1 | 2026-07-31 | **Correction:** added the "Error card" pattern (new §9, Proof renumbered to §10) — [components.md](components.md) had promised this layout was "defined once in patterns.md," but it was never actually written; added now rather than left as a dangling promise. |
