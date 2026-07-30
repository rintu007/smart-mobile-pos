# Device Landscape — Provisional Market (India)

> **Status:** 🟡 Draft — provisional, tied to unconfirmed [OD-01](../01-vision/open-decisions.md)
> **Version:** 0.1.0
> **Last updated:** 2026-07-29
> **Owner:** Principal Flutter Engineer / QA Lead
> **Sources checked:** 2026-07-29

Informs the **reference low-end device** commitment in
[14-testing/README.md](../14-testing/README.md) and assumption [A-01](../01-vision/risks-constraints-assumptions.md).
Provisional on the same basis as [regulatory-notes.md](regulatory-notes.md) — replace if OD-01
resolves to a different market.

---

## Market shape

| Fact | Figure | Design consequence |
| --- | --- | --- |
| Android share | ~92% of the India smartphone market | Android-first is not just a cost decision, it matches where the market already is |
| Budget 5G smartphone price band | ₹13,000–₹25,000 (~US $155–$300) gets a "capable" device with usable camera and battery | This band, not flagship devices, is the realistic device a shop owner or cashier carries — this is our **reference low-end device** territory |
| Offline retail distribution | Offline/physical retail holds >56% of smartphone sales in India | Smartphone retailers are themselves a target vertical (Mobile Shop, per the founding brief's target-business list) — a plausible early-adopter channel worth noting for Phase 16 pilot recruitment |
| Connectivity | Mobile networks are the primary internet access method (low fixed-line broadband penetration); 4G/5G expanding but not uniformly reliable | Reinforces [Principle 1 — Never stop selling](../01-vision/project-vision.md#8-product-principles): intermittent mobile data, not occasional total blackout, is the *normal* condition to design for |

**Sources:** [India Smartphone Market (Statista topic)](https://www.statista.com/topics/4600/smartphone-market-in-india/) ·
[Mobile Phone Price Guide India 2026 (Alibaba)](https://electronics.alibaba.com/buyingguides/india-mobile-price-guide-2026-budget-to-flagship) ·
[India Smartphone Market Size (imarcgroup)](https://www.imarcgroup.com/india-smartphone-market)

---

## What this means for the reference low-end device (Phase 14)

Not a final spec — Phase 14 owns that — but the evidence points toward:

- **RAM:** 3–4 GB is a more realistic "low end in active use" floor than 2 GB for a device bought
  new today, though 2 GB devices remain in the field and should not be silently excluded without a
  measured decision.
- **Android version:** budget devices in this price band commonly ship recent major Android
  versions but with meaningfully weaker CPUs/GPUs than flagship devices at the same OS version — the
  performance budget in [success-metrics.md §3](../01-vision/success-metrics.md) must be verified
  on **actual hardware**, not an emulator, and not a flagship device.
- **Network:** test profiles should include throttled 3G/weak-4G, not just "no connection" — the
  painful case for a synchronous cloud POS is usually a slow, flaky connection, not a clean offline
  state.

**Action for Phase 14:** buy 1–2 actual devices in the ₹13,000–₹18,000 band as the reference
low-end device, rather than assuming a spec.

---

## Bluetooth thermal printers — market reality (informs R-05 / A-07)

| Model class | Observed price (India, 2026) | Notes |
| --- | --- | --- |
| 58mm portable Bluetooth | Commonly available; smaller paper, lower cost | Battery life ~4–5 hrs continuous use cited by multiple listings |
| 80mm portable Bluetooth | ~₹4,950–₹8,000 observed range across listings | Higher-capacity battery (2600 mAh cited), ~3 hr charge time, multi-day standby |
| Command set | ESC/POS is the commonly advertised standard across both sizes | Consistent with our driver-abstraction plan in [R-05](../01-vision/risks-constraints-assumptions.md), but "ESC/POS" is advertised broadly and dialect variation between cheap manufacturers is a known real-world problem this listing data cannot resolve — **only physical testing (A-07) resolves it** |

This is pricing/market-shape evidence, not a compatibility test. It does not close
[A-07](../01-vision/risks-constraints-assumptions.md) — buying three market-typical units and
testing them against our own driver is still a required Phase 10 action.

**Sources:** [Flipkart — Shreyans 80mm listing](https://www.flipkart.com/sestore-in-shreyans-80mm-thermal-receipt-printer-portable-bluetooth-usb-bill-ticket-pos-ios-android-windows-compatible-esc-pos-star-print-commands-set-2600mah-rechargeable-battery/p/itma3bd9f62e609a) ·
general market listings, 2026-07-29.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-29 | Initial research pass, provisional on India as launch market. |
