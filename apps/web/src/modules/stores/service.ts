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
