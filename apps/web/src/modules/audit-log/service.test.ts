import { describe, expect, it, vi, beforeEach } from "vitest";
import * as repository from "./repository";
import { listAuditLog } from "./service";

vi.mock("./repository");

const tenantId = "22222222-2222-4222-8222-222222222222";
const entityId = "66666666-6666-4666-8666-666666666666";

describe("listAuditLog", () => {
  beforeEach(() => vi.resetAllMocks());

  const entry = (id: string, createdAt: Date) => ({
    id,
    storeId: "55555555-5555-4555-8555-555555555555",
    actorUserId: "33333333-3333-4333-8333-333333333333",
    action: "sale.completed",
    entityType: "sale",
    entityId,
    beforeState: null,
    afterState: { status: "completed" },
    createdAt,
  });

  it("returns a non-null next_cursor when more rows exist beyond the requested limit", async () => {
    const rows = [
      entry("a1", new Date("2026-08-01T00:00:00Z")),
      entry("a2", new Date("2026-08-02T00:00:00Z")),
      entry("a3", new Date("2026-08-03T00:00:00Z")),
    ];
    vi.mocked(repository.listAuditLog).mockResolvedValue(rows as never);

    const result = await listAuditLog(tenantId, { limit: 2 });

    expect(result.data).toHaveLength(2);
    expect(result.next_cursor).not.toBeNull();
  });

  it("returns a null next_cursor when the page is partial (end of data)", async () => {
    vi.mocked(repository.listAuditLog).mockResolvedValue([
      entry("a1", new Date("2026-08-01T00:00:00Z")),
    ] as never);

    const result = await listAuditLog(tenantId, { limit: 50 });

    expect(result.next_cursor).toBeNull();
  });

  it("passes entity_type/entity_id/date filters through to the repository", async () => {
    vi.mocked(repository.listAuditLog).mockResolvedValue([] as never);

    await listAuditLog(tenantId, {
      limit: 50,
      entity_type: "sale",
      entity_id: entityId,
      date_from: "2026-08-01T00:00:00.000Z",
      date_to: "2026-08-14T00:00:00.000Z",
    });

    expect(repository.listAuditLog).toHaveBeenCalledWith(
      tenantId,
      {
        entityType: "sale",
        entityId,
        dateFrom: new Date("2026-08-01T00:00:00.000Z"),
        dateTo: new Date("2026-08-14T00:00:00.000Z"),
      },
      null,
      50,
    );
  });

  it("rejects a malformed cursor with VALIDATION_FAILED rather than crashing", async () => {
    await expect(listAuditLog(tenantId, { cursor: "not-a-real-cursor!!", limit: 50 })).rejects.toMatchObject({
      status: 422,
      code: "VALIDATION_FAILED",
    });
  });
});
