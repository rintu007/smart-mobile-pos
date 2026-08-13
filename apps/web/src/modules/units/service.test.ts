import { describe, expect, it, vi, beforeEach } from "vitest";
import * as identityService from "@/modules/identity/service";
import * as repository from "./repository";
import { createUnit, listUnits } from "./service";
import type { CreateUnitRequest } from "./schema";

vi.mock("./repository");
vi.mock("@/modules/identity/service");

const authUserId = "11111111-1111-4111-8111-111111111111";
const tenantId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";

const input: CreateUnitRequest = {
  id: "44444444-4444-4444-8444-444444444444",
  name: "Kilogram",
  symbol: "kg",
  allows_fractional: true,
};

describe("createUnit", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(userId);
  });

  it("resolves the internal user id and creates the unit under it", async () => {
    vi.mocked(repository.createUnit).mockResolvedValue({
      id: input.id,
      tenantId,
      name: input.name,
      symbol: input.symbol,
      allowsFractional: input.allows_fractional,
      createdAt: new Date("2026-08-14T00:00:00Z"),
      createdBy: userId,
    } as never);

    const result = await createUnit(authUserId, tenantId, input);

    expect(identityService.resolveUserId).toHaveBeenCalledWith(authUserId);
    expect(repository.createUnit).toHaveBeenCalledWith({ ...input, tenantId, createdBy: userId });
    expect(result).toEqual({
      id: input.id,
      name: input.name,
      symbol: input.symbol,
      allows_fractional: true,
      created_at: "2026-08-14T00:00:00.000Z",
    });
  });
});

describe("listUnits", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  const unit = (id: string, createdAt: Date) => ({
    id,
    tenantId,
    name: "Unit",
    symbol: "u",
    allowsFractional: false,
    createdAt,
    createdBy: userId,
  });

  it("returns a non-null next_cursor when more rows exist beyond the requested limit", async () => {
    const rows = [
      unit("u1", new Date("2026-08-01T00:00:00Z")),
      unit("u2", new Date("2026-08-02T00:00:00Z")),
      unit("u3", new Date("2026-08-03T00:00:00Z")),
    ];
    vi.mocked(repository.listUnits).mockResolvedValue(rows as never);

    const result = await listUnits(tenantId, undefined, 2);

    expect(result.data).toHaveLength(2);
    expect(result.data.map((u) => u.id)).toEqual(["u1", "u2"]);
    expect(result.next_cursor).not.toBeNull();
  });

  it("returns a null next_cursor when the page is partial (end of data)", async () => {
    const rows = [unit("u1", new Date("2026-08-01T00:00:00Z"))];
    vi.mocked(repository.listUnits).mockResolvedValue(rows as never);

    const result = await listUnits(tenantId, undefined, 50);

    expect(result.next_cursor).toBeNull();
  });

  it("rejects a malformed cursor with VALIDATION_FAILED rather than crashing", async () => {
    await expect(listUnits(tenantId, "not-a-real-cursor!!", 50)).rejects.toMatchObject({
      status: 422,
      code: "VALIDATION_FAILED",
    });
  });
});
