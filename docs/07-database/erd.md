# Entity Relationship Diagrams

> **Status:** 🔵 In review
> **Phase:** 07 — Database Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** PostgreSQL Architect
> **Approved by:** _pending_

Seven bounded contexts, each a Mermaid `erDiagram`. Full column-level detail is in
[schema-server.md](schema-server.md) — these diagrams show shape and relationships, not every
column. Two stub tables (`product_variants`, `batches`) exist with no V1 write path, satisfying this
phase's exit criterion that variants/batch/expiry/serial are accommodated now.

---

## 1. Identity & Tenancy

```mermaid
erDiagram
    TENANTS ||--o{ STORES : owns
    TENANTS ||--o{ USERS : has
    USERS ||--o{ USER_STORE_ROLES : "assigned via"
    STORES ||--o{ USER_STORE_ROLES : "scoped to"
    USERS ||--o{ DEVICES : "authenticates from"
    TENANTS ||--o{ AUDIT_LOG : "scoped to"

    TENANTS {
        uuid id PK
        text name
        timestamptz deactivated_at
    }
    STORES {
        uuid id PK
        uuid tenant_id FK
        text name
        timestamptz deactivated_at
    }
    USERS {
        uuid id PK
        uuid tenant_id FK
        uuid auth_user_id
        text display_name
        timestamptz deactivated_at
    }
    USER_STORE_ROLES {
        uuid id PK
        uuid user_id FK
        uuid store_id FK
        text role
        uuid assigned_by FK
        timestamptz revoked_at
    }
    DEVICES {
        uuid id PK
        uuid user_id FK
        text client_device_id
        timestamptz revoked_at
    }
    AUDIT_LOG {
        uuid id PK
        uuid tenant_id FK
        uuid store_id FK
        uuid actor_user_id FK
        text action
        text entity_type
        uuid entity_id
    }
```

## 2. Catalogue (tenant-scoped, not store-scoped — see [tenancy-model.md](tenancy-model.md))

```mermaid
erDiagram
    TENANTS ||--o{ CATEGORIES : has
    TENANTS ||--o{ UNITS : has
    TENANTS ||--o{ PRODUCTS : has
    CATEGORIES ||--o{ PRODUCTS : classifies
    UNITS ||--o{ PRODUCTS : "measured in"
    PRODUCTS ||--o{ PRODUCT_VARIANTS : "may have (V2+, stub only)"

    CATEGORIES {
        uuid id PK
        uuid tenant_id FK
        text name
        timestamptz deactivated_at
    }
    UNITS {
        uuid id PK
        uuid tenant_id FK
        text name
        boolean allows_fractional
        timestamptz deactivated_at
    }
    PRODUCTS {
        uuid id PK
        uuid tenant_id FK
        uuid category_id FK
        uuid unit_id FK
        text name
        text sku
        text barcode
        text hsn_sac_code
        bigint price_minor_units
        timestamptz deactivated_at
    }
    PRODUCT_VARIANTS {
        uuid id PK
        uuid tenant_id FK
        uuid product_id FK
        jsonb variant_attributes
        text sku
        text barcode
        timestamptz deactivated_at
    }
```

## 3. Inventory (store-scoped)

```mermaid
erDiagram
    STORES ||--o{ STOCK_MOVEMENTS : "recorded at"
    PRODUCTS ||--o{ STOCK_MOVEMENTS : concerns
    PRODUCT_VARIANTS ||--o{ STOCK_MOVEMENTS : "may concern (V2+)"
    BATCHES ||--o{ STOCK_MOVEMENTS : "may concern (V4, stub only)"

    STOCK_MOVEMENTS {
        uuid id PK
        uuid tenant_id FK
        uuid store_id FK
        uuid product_id FK
        uuid variant_id FK
        uuid batch_id FK
        text serial_number
        numeric quantity_delta
        text movement_type
        text reason_code
        text reference_type
        uuid reference_id
        uuid client_operation_id
        uuid device_id FK
    }
    BATCHES {
        uuid id PK
        uuid tenant_id FK
        uuid product_id FK
        text batch_number
        date expiry_date
    }
```

**No `UPDATE`/`DELETE` grant exists on `STOCK_MOVEMENTS` for any role** —
[ADR-0005](../adr/ADR-0005-append-only-stock-ledger.md). Balance is always
`SUM(quantity_delta)`, never a stored column.

## 4. Customers (tenant-scoped)

```mermaid
erDiagram
    TENANTS ||--o{ CUSTOMERS : has
    CUSTOMERS ||--o{ SALES : "attached to (optional)"

    CUSTOMERS {
        uuid id PK
        uuid tenant_id FK
        text name
        text phone
        timestamptz deactivated_at
    }
```

## 5. Sales (store-scoped)

```mermaid
erDiagram
    STORES ||--o{ TRADING_DAYS : "opened at"
    DEVICES ||--o{ TRADING_DAYS : "scoped to (V1)"
    TRADING_DAYS ||--o{ SALES : "occur within"
    STORES ||--o{ SALES : "recorded at"
    CUSTOMERS ||--o{ SALES : "optionally attached"
    SALES ||--|{ SALE_LINE_ITEMS : contains
    SALES ||--o{ SALE_PAYMENTS : "settled by"
    PRODUCTS ||--o{ SALE_LINE_ITEMS : sold
    SALES ||--o{ STOCK_MOVEMENTS : "generates (movement_type=sale)"

    TRADING_DAYS {
        uuid id PK
        uuid tenant_id FK
        uuid store_id FK
        uuid device_id FK
        text status
        bigint starting_float_minor_units
        bigint counted_cash_minor_units
        bigint expected_cash_minor_units
        bigint variance_minor_units
    }
    SALES {
        uuid id PK
        uuid tenant_id FK
        uuid store_id FK
        uuid device_id FK
        uuid trading_day_id FK
        uuid customer_id FK
        text provisional_invoice_number
        bigint canonical_invoice_number
        text tax_registration_type_at_sale
        text status
        bigint grand_total_minor_units
        uuid client_operation_id
    }
    SALE_LINE_ITEMS {
        uuid id PK
        uuid sale_id FK
        uuid product_id FK
        uuid variant_id FK
        numeric quantity
        bigint unit_price_minor_units
        integer tax_rate_basis_points
        bigint line_tax_minor_units
        bigint line_total_minor_units
    }
    SALE_PAYMENTS {
        uuid id PK
        uuid sale_id FK
        text method
        bigint amount_minor_units
    }
```

## 6. Returns (store-scoped)

```mermaid
erDiagram
    SALES ||--o{ RETURNS : "reversed (in part) by"
    SALE_LINE_ITEMS ||--o{ RETURN_LINE_ITEMS : "returned via"
    RETURNS ||--|{ RETURN_LINE_ITEMS : contains
    RETURNS ||--o{ STOCK_MOVEMENTS : "generates (movement_type=return)"

    RETURNS {
        uuid id PK
        uuid tenant_id FK
        uuid store_id FK
        uuid original_sale_id FK
        text status
        bigint refund_total_minor_units
        uuid approved_by FK
        uuid client_operation_id
    }
    RETURN_LINE_ITEMS {
        uuid id PK
        uuid return_id FK
        uuid original_sale_line_item_id FK
        numeric quantity
        bigint refund_amount_minor_units
    }
```

## 7. Settings & Sync (tenant-scoped)

```mermaid
erDiagram
    TENANTS ||--|| SHOP_SETTINGS : configures
    TENANTS ||--o{ IDEMPOTENCY_KEYS : tracks
    TENANTS ||--o{ SYNC_REJECTIONS : records

    SHOP_SETTINGS {
        uuid tenant_id PK_FK
        text tax_mode
        text pricing_mode
        text rounding_rule
        text currency_code
        bigint discount_auto_approval_threshold_minor_units
        bigint return_auto_approval_threshold_minor_units
        jsonb printer_config
        jsonb receipt_template_config
    }
    IDEMPOTENCY_KEYS {
        uuid client_operation_id PK
        uuid tenant_id FK
        text operation_type
        uuid entity_id
        timestamptz first_seen_at
    }
    SYNC_REJECTIONS {
        uuid id PK
        uuid tenant_id FK
        uuid store_id FK
        uuid device_id FK
        text entity_type
        uuid local_entity_id
        text reason
        timestamptz resolved_at
    }
```

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial 7 bounded-context ERDs, including 2 forward-accommodation stub tables. |
