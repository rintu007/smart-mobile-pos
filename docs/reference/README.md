# Reference

> **Status:** 🔵 In review
> **Version:** 0.1.0
> **Last updated:** 2026-07-28
> **Owner:** CTO

External research and vendor facts that inform decisions but are not decisions themselves.

**Rule:** everything here carries a **source and a date checked**. Vendor limits, licence terms and
pricing change without notice, and a fact recorded from memory is a fact that will eventually be
wrong at an expensive moment.

## Contents

| Document | Purpose | Needed by | Status |
| --- | --- | --- | --- |
| [`vendor-limits.md`](vendor-limits.md) | Free/paid tier limits, licence terms, commercial-use restrictions, inactivity policies, overage rates — sourced 2026-07-29 | Phase 02 (R-01, OD-02) | 🟢 Researched |
| [`competitor-teardown.md`](competitor-teardown.md) | Loyverse, Vyapar, Zoho POS, Marg ERP: pricing, feature boundaries, observed weaknesses | Phase 02 | 🟢 Researched |
| [`regulatory-notes.md`](regulatory-notes.md) | Tax model, receipt requirements, invoice numbering law, data residency — provisional on India | Phase 02 (R-06, OD-01) | 🟡 Provisional, secondary sources only |
| `printer-compatibility.md` | Tested Bluetooth thermal printers: model, command set, paper width, pairing quirks | Phase 10 (R-05, A-07) | ⚪ Not started — requires physical hardware, cannot be desk-researched |
| [`device-landscape.md`](device-landscape.md) | Devices actually owned by target shops; the basis for the reference low-end device — provisional on India | Phase 14 (A-01) | 🟡 Provisional |
| [`payment-providers.md`](payment-providers.md) | Providers available in the launch market: fees, settlement, integration effort — provisional on India | Phase 02, V3 | 🟡 Provisional |

## Rules

- Every claim states its source and the date it was checked.
- Anything older than six months is re-verified before it is used to make a decision.
- Research is recorded here; the decision it supports goes in an ADR. This folder never contains
  decisions.
