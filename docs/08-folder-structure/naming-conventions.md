# Naming Conventions

> **Status:** 🔵 In review
> **Phase:** 08 — Folder Structure
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Chief Software Architect
> **Approved by:** _pending_

Reference conventions across every layer touched by this project. Where a language has an
established official style guide, this document adopts it rather than inventing a competing one —
consistent with [project-vision.md §8](../01-vision/project-vision.md) Principle 7 (boring, proven
choices).

---

## Dart / Flutter (`apps/mobile`)

Follows [Effective Dart](https://dart.dev/effective-dart) conventions:

| Element | Convention | Example |
| --- | --- | --- |
| File names | `snake_case.dart` | `product_repository.dart` |
| Classes, enums, typedefs | `PascalCase` | `StockMovement`, `SaleStatus` |
| Variables, functions, parameters | `camelCase` | `quantityDelta`, `computeLineTax()` |
| Constants | `camelCase` (not `SCREAMING_CASE` — Effective Dart's own guidance) | `defaultRoundingRule` |
| Private members | Leading underscore | `_localSequence` |
| Folders | `snake_case` | `features/cash_drawer/` |

## TypeScript (`apps/web`)

| Element | Convention | Example |
| --- | --- | --- |
| File names | `kebab-case.ts` | `stock-movement.service.ts` |
| Classes, types, interfaces | `PascalCase` | `StockMovement`, `SaleStatus` |
| Variables, functions | `camelCase` | `quantityDelta`, `computeLineTax()` |
| Constants (module-level, truly fixed) | `SCREAMING_SNAKE_CASE` | `DEFAULT_ROUNDING_RULE` |
| Folders | `kebab-case` | `modules/cash-drawer/` |
| Route Handler files | Next.js convention — always `route.ts` within the resource's folder | `app/api/v1/sales/route.ts` |

## PostgreSQL (`schema-server.md`)

Already applied consistently throughout Phase 07 — restated here as the binding rule, not a new
decision:

| Element | Convention | Example |
| --- | --- | --- |
| Tables | `snake_case`, plural | `stock_movements`, `sale_line_items` |
| Columns | `snake_case`, singular | `quantity_delta`, `created_at` |
| Primary keys | Always `id` | — |
| Foreign keys | `<referenced_table_singular>_id` | `product_id`, `store_id` |
| Booleans | `is_`/`has_`/`allows_` prefix | `allows_fractional` |
| Enums (via `CHECK` constraint, not native Postgres `ENUM` — easier to extend without a migration) | `snake_case` string values | `'pending_approval'` |

## API routes

REST-conventional, versioned, kebab-case, plural nouns:

```
/api/v1/sales
/api/v1/sales/{id}
/api/v1/stock-movements
/api/v1/returns/{id}/approve      # verb-as-sub-resource for actions that aren't plain CRUD
```

## Requirement and decision IDs

Already fixed in [documentation-standards.md](../00-governance/documentation-standards.md) —
`BR-NNN`, `FR-NNN`, `NFR-NNN`, `US-NNN`, `RR-NNN`, `DR-NNN`, `ADR-NNNN`, `WF-NNN`, `TB-N`, `QA-NNN`.
Not repeated here in full; cross-referenced because a naming-conventions document would be
incomplete without acknowledging these already exist.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial conventions across Dart, TypeScript, PostgreSQL, and API routes. |
