import { describe, expect, it, vi, beforeEach } from "vitest";
import * as repository from "./repository";
import { listStores } from "./service";

vi.mock("./repository");

const tenantId = "22222222-2222-4222-8222-222222222222";

describe("listStores", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("returns the tenant's store(s), shaped for the API response", async () => {
    vi.mocked(repository.listByTenant).mockResolvedValue([
      {
        id: "store-1",
        tenantId,
        name: "Main Store",
        address: "123 MG Road",
        deactivatedAt: null,
        createdAt: new Date("2026-08-01T00:00:00Z"),
        createdBy: "user-1",
      },
    ] as never);

    const result = await listStores(tenantId);

    expect(repository.listByTenant).toHaveBeenCalledWith(tenantId);
    expect(result).toEqual([{ id: "store-1", name: "Main Store", address: "123 MG Road" }]);
  });

  it("passes through a null address unchanged", async () => {
    vi.mocked(repository.listByTenant).mockResolvedValue([
      {
        id: "store-1",
        tenantId,
        name: "Main Store",
        address: null,
        deactivatedAt: null,
        createdAt: new Date(),
        createdBy: "user-1",
      },
    ] as never);

    const result = await listStores(tenantId);

    expect(result[0]!.address).toBeNull();
  });
});
