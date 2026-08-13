import { describe, expect, it, vi, beforeEach } from "vitest";
import * as identityService from "@/modules/identity/service";
import * as repository from "./repository";
import { createCategory, listCategories } from "./service";
import type { CreateCategoryRequest } from "./schema";

vi.mock("./repository");
vi.mock("@/modules/identity/service");

const authUserId = "11111111-1111-4111-8111-111111111111";
const tenantId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";

const input: CreateCategoryRequest = {
  id: "44444444-4444-4444-8444-444444444444",
  name: "Beverages",
};

describe("createCategory", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(identityService.resolveUserId).mockResolvedValue(userId);
  });

  it("resolves the internal user id and creates the category under it", async () => {
    vi.mocked(repository.createCategory).mockResolvedValue({
      id: input.id,
      tenantId,
      name: input.name,
      createdAt: new Date("2026-08-14T00:00:00Z"),
      createdBy: userId,
    } as never);

    const result = await createCategory(authUserId, tenantId, input);

    expect(identityService.resolveUserId).toHaveBeenCalledWith(authUserId);
    expect(repository.createCategory).toHaveBeenCalledWith({ ...input, tenantId, createdBy: userId });
    expect(result).toEqual({
      id: input.id,
      name: input.name,
      created_at: "2026-08-14T00:00:00.000Z",
    });
  });
});

describe("listCategories", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  const category = (id: string, createdAt: Date) => ({
    id,
    tenantId,
    name: "Cat",
    createdAt,
    createdBy: userId,
  });

  it("returns a non-null next_cursor when more rows exist beyond the requested limit", async () => {
    const rows = [
      category("c1", new Date("2026-08-01T00:00:00Z")),
      category("c2", new Date("2026-08-02T00:00:00Z")),
      category("c3", new Date("2026-08-03T00:00:00Z")),
    ];
    vi.mocked(repository.listCategories).mockResolvedValue(rows as never);

    const result = await listCategories(tenantId, undefined, 2);

    expect(result.data).toHaveLength(2);
    expect(result.data.map((c) => c.id)).toEqual(["c1", "c2"]);
    expect(result.next_cursor).not.toBeNull();
  });

  it("returns a null next_cursor when the page is partial (end of data)", async () => {
    const rows = [category("c1", new Date("2026-08-01T00:00:00Z"))];
    vi.mocked(repository.listCategories).mockResolvedValue(rows as never);

    const result = await listCategories(tenantId, undefined, 50);

    expect(result.next_cursor).toBeNull();
  });

  it("rejects a malformed cursor with VALIDATION_FAILED rather than crashing", async () => {
    await expect(listCategories(tenantId, "not-a-real-cursor!!", 50)).rejects.toMatchObject({
      status: 422,
      code: "VALIDATION_FAILED",
    });
  });
});
