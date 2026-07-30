# Glossary

> **Status:** 🟡 Draft — grows with every phase
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** Business Analyst / CTO

Shared vocabulary. Ambiguous terms cause defects: two people implementing "stock" as different
things produces a bug that no test catches, because both halves match their author's definition.

**Rule:** any term used in a specification with a domain-specific meaning is defined here, in the
same pull request that introduces it.

---

## Product and business

| Term | Definition |
| --- | --- |
| **Tenant** | One business account. The top-level isolation boundary. All data belongs to exactly one tenant. |
| **Store / Outlet** | A physical selling location belonging to a tenant. V1 creates exactly one and hides the concept; the schema supports many from day one. |
| **Terminal / Device** | An installed instance of the app, bound to one user and one store. Relevant to offline invoice numbering. |
| **Shop owner** | The primary persona. Buyer, administrator and frequently the cashier. |
| **Trading day** | The period between a cash drawer opening and its closing. Not necessarily a calendar day. |

## Catalogue

| Term | Definition |
| --- | --- |
| **Product** | A sellable item. |
| **Variant** | A specific sellable configuration of a product (size, colour, weight). Deferred to V2; accommodated in the V1 schema. |
| **SKU** | Stock Keeping Unit. The tenant's own internal identifier for a stocked item. Unique within a tenant. |
| **Barcode** | A manufacturer or tenant-assigned scannable code. Distinct from SKU: one product may have several barcodes. |
| **Unit** | The measure a product is sold in — piece, kilogram, litre, packet. |
| **Category** | A single-level grouping of products for browsing and reporting. |

## Inventory

| Term | Definition |
| --- | --- |
| **Stock movement** | An immutable record of a quantity change: what, where, how much, why, by whom, when. The atomic unit of inventory. **Never edited or deleted.** |
| **Stock ledger** | The append-only collection of all stock movements. The authoritative record of inventory. |
| **Stock balance** | A *derived* quantity: the sum of movements for a product at a store. Never authored directly, never stored as a client-writable value. |
| **Opening stock** | The movement that establishes an initial quantity when a product first enters the system. |
| **Stock adjustment** | A movement recording a correction, with a mandatory reason — damage, loss, expiry, count correction. |
| **Overselling** | Completing a sale that takes stock below zero. A recorded, alerted business event — not an error, and not a sync conflict. |
| **Batch** | A group of units sharing a manufacture or expiry date. Deferred to V4 (pharmacy). |

## Sales

| Term | Definition |
| --- | --- |
| **Sale** | A completed transaction. **Immutable once completed.** Corrections are new linked events. |
| **Draft sale** | The active, in-progress cart being built for the customer currently at the till — the default working state from the moment the first item is added. Not a sale; consumes no stock. See [state-machines.md](06-workflows/state-machines.md#sale) and [navigation-model.md §4](09-navigation/navigation-model.md#4-resolving-the-mid-sale-interruption-requirement). |
| **Held sale** | A draft cart explicitly set aside by the Cashier so the terminal can serve another customer — a distinct state from Draft, reached only by an explicit "Hold" action, per [WF-005](06-workflows/sales-workflows.md#wf-005--hold-and-resume-a-sale). Not a sale; consumes no stock. |
| **Invoice** | The formal, numbered document representing a sale. |
| **Provisional invoice number** | A device-scoped number assigned offline. Preserved and mapped after sync — **never renumbered**, because renumbering breaks the audit trail. |
| **Return** | Goods coming back, generating a reversing stock movement and a monetary outcome. |
| **Refund** | Money returned to the customer. |
| **Exchange** | A return plus a new sale in one transaction. |
| **Store credit** | A monetary balance held for a customer, spendable in the shop. A liability of the business. |
| **Split payment** | One sale settled across multiple payment methods. |
| **Partial payment** | One sale settled across multiple points in time, leaving a balance owed. |

## Money

| Term | Definition |
| --- | --- |
| **Minor unit** | The smallest indivisible amount of a currency (cent, paisa, poisha). **All money is stored as an integer count of minor units.** |
| **Tax-inclusive pricing** | The displayed price contains tax. |
| **Tax-exclusive pricing** | Tax is added at the point of sale. |
| **Rounding rule** | The tenant-configured method for resolving sub-minor-unit amounts. Specified explicitly because inconsistency here produces reconciliation disputes. |

## Synchronisation

| Term | Definition |
| --- | --- |
| **Offline-first** | The local database is authoritative at the point of sale. The server is authoritative for the business. Offline is the normal operating mode, not an error state. |
| **Outbound queue** | The durable, ordered list of local operations awaiting transmission. Survives app kill and device reboot. |
| **Idempotency key** | A client-generated identifier that lets the server recognise a retry and refuse to apply it twice. |
| **Delta** | A relative change ("−1"). Deltas compose under concurrency; absolute values collide. Clients send deltas for anything countable. |
| **Immutable event** | An entity class that is client-created, append-only and cannot conflict. Sales and stock movements are immutable events. |
| **Server-authoritative** | An entity class that mobile clients read but do not write offline. Products, prices and permissions are server-authoritative. |
| **Derived** | An entity class that is never synchronised because it is recomputed locally from events. Stock balances are derived. |
| **Conflict** | Two devices producing incompatible states for the same client-editable entity. By design, sales and stock cannot conflict. |
| **Hydration** | The initial population of a new device's local database from the server. |

## Security

| Term | Definition |
| --- | --- |
| **Row Level Security (RLS)** | Database-enforced row visibility. Our **second** line of tenant isolation behind every API-fronted boundary — **except direct Realtime read subscriptions (trust boundary TB-2), where no API layer sits in front of it and RLS is the sole gate**; see [system-context.md §4](04-srs/system-context.md#4-trust-boundaries--the-list-phase-12-inherits) and [tenant-isolation.md](12-security/tenant-isolation.md). |
| **Permission** | A named capability, such as `sale.discount.apply`. Roles are collections of permissions. |
| **Audit log** | The append-only record of every action affecting money, stock or permissions. Not modifiable by any application code path. |
| **Trust boundary** | A point where data crosses between components with different trust levels. Each one is threat-modelled in Phase 12. |

## Process

| Term | Definition |
| --- | --- |
| **ADR** | Architecture Decision Record. Immutable once accepted; superseded, never edited. |
| **Definition of Done** | The complete checklist a module satisfies before it counts as delivered. No partial credit. |
| **Release slice** | A coherent group of modules shipped together — V1 through V4. |
| **Reference low-end device** | The physical device performance is measured on. Named in Phase 14. Development machines are not evidence. |
