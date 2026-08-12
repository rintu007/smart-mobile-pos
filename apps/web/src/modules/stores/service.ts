import * as repository from "./repository";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

/**
 * docs/modules/company-store-setup/specification.md#4-api-contract,
 * docs/11-api/endpoints/identity.md#stores. V1 always returns exactly one store per tenant
 * (ADR-0003) — no selector shown, the caller uses the single result.
 */
export async function listStores(tenantId: string) {
  const stores = await repository.listByTenant(tenantId);

  return stores.map((store) => ({
    id: store.id,
    name: store.name,
    address: store.address,
  }));
}

/**
 * The tenant's one store's id — used server-side wherever a caller needs a `store_id` without
 * exposing store selection (ADR-0003: V1 is always exactly one store per tenant). Throws if none
 * exists, which should never happen since onboarding always creates a tenant and its store
 * together (Sprint 02) — a genuine invariant violation, not a validated user-facing case.
 */
export async function getPrimaryStoreId(tenantId: string) {
  const [store] = await repository.listByTenant(tenantId);
  if (!store) {
    throw new Error(`No store found for tenant ${tenantId} — onboarding should have created one.`);
  }
  return store.id;
}
