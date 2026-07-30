# Endpoints — Index

One document per backend module, mirroring [backend-structure.md](../../08-folder-structure/backend-structure.md)'s
module-to-table mapping exactly — a module's endpoint document exists if and only if the module
exists in that mapping.

| Module document | Owns tables |
| --- | --- |
| [identity.md](identity.md) | `stores`, `users`, `user_store_roles`, `devices`, `audit_log` |
| [catalogue.md](catalogue.md) | `categories`, `units`, `products` (`product_variants` — no endpoint yet, V2+ stub) |
| [inventory.md](inventory.md) | `stock_movements` |
| [customers.md](customers.md) | `customers` |
| [sales.md](sales.md) | `trading_days`, `sales`, `sale_line_items`, `sale_payments` |
| [returns.md](returns.md) | `returns`, `return_line_items` |
| [settings.md](settings.md) | `shop_settings` |

`idempotency_keys` and `sync_rejections` (the `sync` module's tables) have no direct client-facing
endpoints of their own — they are read and written as a side effect of [sync-api.md](../sync-api.md),
which is documented separately since it is a batch protocol, not a resource CRUD surface.
