# Sprint 16

> **Dates:** 2026-08-13 – 2026-08-14
> **Milestone:** M0 — Walking Skeleton (backlog item 11 — the exit criterion itself)
> **Status:** In progress — steps 1–7 confirmed working by the founder 2026-08-14; step 8 (print)
> remains open, blocked on physical printer hardware

## Goal

Run [milestones.md — M0](../16-milestones/milestones.md#m0--walking-skeleton)'s exact exit
criterion, for real, on the founder's own phone, and evidence it —
[backlog.md item 11](backlog.md#1-m0--walking-skeleton-fully-decomposed), the last M0 item.
This sprint writes **no new code** — every capability it exercises was built and unit/live-verified
across Sprints 01–15. Its only deliverable is the proof itself.

## Why this is a sprint, not just "done" once the code exists

Every prior M0 item was individually built and individually verified (unit tests, live database
checks, `flutter test`), but **nothing has yet run the full sequence end to end, on one device, in
one session** — sign in → add a product → sell it fully offline → reconnect → watch that sale
actually reach the server → print the receipt. Phase 16's own rule for M0 is explicit that this is
the point: "a live phone, in front of the founder, completing exactly that sequence — not a
description of it." A sprint whose entire content is running that sequence and recording the
result is exactly what this phase anticipated, not scope invented late.

## Scope

| Item | Depends on | Estimate (person-days) |
| --- | --- | --- |
| End-to-end proof: sign in, add a product, complete a sale in airplane mode, reconnect, watch it sync, print the receipt — executed and evidenced | 1–10, 12 (all done) | 1 |

## What this sprint prepared (engineering side)

- Rebuilt release APK (`flutter build apk --release --dart-define-from-file=dart_define.json`)
  containing every Sprint 11–15 change (stock ledger, audit log, both sync-engine halves, receipt
  printing) — the founder's currently-installed app (from Sprint 10) predates all of it.
- Re-served the updated APK via the same local network file share Sprint 10 already established
  (`http://192.168.0.100:8642/smartpos-x.apk`), fixed for the per-request `Content-Length` bug found
  and fixed mid-session.
- The exact step-by-step script below, cross-referenced against what each step's underlying
  screen/provider actually is, so "watch it sync" has a concrete, observable signal
  (`sync_status` on the home screen) rather than an ambiguous instruction.

## The script — what the founder actually runs

1. **Install the rebuilt APK** over the existing app (same package, same account — "Gadgets
   Kolkata" data is preserved, not reset).
2. **Sign in** (if not already) — `/auth/login`.
3. **Turn on airplane mode.**
4. **Add a product** — the `+` FAB on the home screen (`/catalogue/add`), any name/price.
5. **Sell it** — go to the till (`/pos`), tap the product, complete the cash sale.
6. **Turn airplane mode back off.**
7. **Watch it sync** — return to the home screen. The `sync_status` line should move from "Not
   synced yet this session" to a summary showing at least 2 accepted operations (the product and
   the sale) once the automatic on-start trigger fires, or tap "Sync now" directly to force it
   immediately rather than waiting.
8. **Print the receipt** — open the sale just completed from sales history (`/sales-history`), tap
   the print icon, pick the paired printer, confirm a physical receipt comes out matching
   [receipt-design.md §3](../10-design-system/receipt-design.md#3-worked-example--58-mm)'s
   structure (narrowed to M0's fields, per
   [receipt-printing/specification.md](../modules/receipt-printing/specification.md)).

## Confirmation — 2026-08-14

Founder ran steps 1–7 on the rebuilt APK, on the real "Gadgets Kolkata" account and device: sign
in, airplane mode, add a product, sell it, reconnect, sync. Confirmed working — no crash, no hang,
sale and product both reached the server. No new bug found, unlike Sprints 04/05/08/etc.'s own
first-real-contact pattern of finding something on the first live attempt; the individually-proven
pieces held together as a sequence on the first real end-to-end run.

## Blockers — named, not glossed over

- **Step 8 needs a real Bluetooth ESC/POS printer** — confirmed 2026-08-13: the founder does not
  have one yet, matching what [Sprint 15](sprint-15.md#risks) already flagged as unavailable in
  this engineering environment too. Same category as
  [device-matrix.md §3](../14-testing/device-matrix.md#3-this-is-a-founder-action-not-an-engineering-one--stated-plainly)'s
  physical reference device — not something either side can force. **This sprint's scope is
  therefore narrowed to steps 1–7 for now**; step 8 stays open, tracked separately, until a printer
  is on hand.
- **Steps 1–7 need the founder's own hands** — signing in, toggling airplane mode, and tapping
  through the app on a physical phone are not actions this session can perform remotely.

## Definition of Done

- [x] Steps 1–7 run on the founder's own device, confirmed working 2026-08-14 (product and sale
      both synced; no crash or hang at any step) — reported directly by the founder ("checked and
      its fine"), no bug found.
- [ ] Step 8 run against a real printer, physical receipt photographed or described — **pending
      printer hardware, confirmed unavailable as of 2026-08-13**; tracked separately, revisited
      once the founder has one.
- [x] Any real bug found during the run is logged and fixed before this sprint (and M0 itself)
      closes — matching every prior sprint's own "real HTTP request/live verification" addendum
      rule, now applied to the full sequence at once rather than one endpoint at a time. None found
      this run.
- [ ] `milestones.md`'s M0 row marked demonstrated — **not yet**: M0's own exit criterion is the
      full sequence including the physical print, so M0 stays open until step 8 closes too.
- [x] `backlog.md` item 11 and this document updated to record steps 1–7's confirmation.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-13 | Sprint 16 opened: M0's own exit-criterion sequence scripted precisely against what Sprints 01–15 actually built; rebuilt APK prepared and re-served. Waiting on the founder to run steps 1–7 now and step 8 once a physical printer is available. |
| 0.2.0 | 2026-08-14 | Steps 1–7 confirmed working by the founder — no bug found. Step 8 (physical print) remains open, still blocked on printer hardware; M0 itself stays open until it closes too. |
