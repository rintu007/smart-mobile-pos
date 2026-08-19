import { beforeEach, describe, expect, it, vi } from "vitest";
import * as repository from "./repository";
import { assertDeviceUsable, listDevices, registerDevice, revokeDevice } from "./service";

vi.mock("./repository");

const userId = "11111111-1111-4111-8111-111111111111";
const tenantId = "22222222-2222-4222-8222-222222222222";
const deviceId = "33333333-3333-4333-8333-333333333333";
const clientDeviceId = "install-abc123";

function deviceRow(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    id: deviceId,
    userId,
    clientDeviceId,
    lastSeenAt: new Date("2026-08-20T10:00:00Z"),
    revokedAt: null,
    revokedBy: null,
    createdAt: new Date("2026-08-20T09:00:00Z"),
    createdBy: userId,
    ...overrides,
  };
}

describe("registerDevice", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("formats the upserted row, including a null last_seen_at/revoked_at as null, not undefined", async () => {
    vi.mocked(repository.registerDevice).mockResolvedValue(deviceRow() as never);

    const result = await registerDevice(userId, clientDeviceId);

    expect(result).toEqual({
      id: deviceId,
      client_device_id: clientDeviceId,
      last_seen_at: "2026-08-20T10:00:00.000Z",
      revoked_at: null,
      revoked_by: null,
      created_at: "2026-08-20T09:00:00.000Z",
    });
  });
});

describe("listDevices", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("formats every row returned for the tenant", async () => {
    vi.mocked(repository.listDevicesForTenant).mockResolvedValue([
      deviceRow(),
      deviceRow({ id: "44444444-4444-4444-8444-444444444444", clientDeviceId: "install-xyz" }),
    ] as never);

    const result = await listDevices(tenantId);

    expect(result).toHaveLength(2);
    expect(result.map((d) => d.client_device_id)).toEqual(["install-abc123", "install-xyz"]);
  });
});

describe("revokeDevice", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("throws NOT_FOUND for a device outside this tenant (or that doesn't exist)", async () => {
    vi.mocked(repository.findByIdForTenant).mockResolvedValue(null);

    await expect(revokeDevice(tenantId, deviceId, userId)).rejects.toMatchObject({
      status: 404,
      code: "NOT_FOUND",
    });
  });

  it("revokes a not-yet-revoked device", async () => {
    vi.mocked(repository.findByIdForTenant).mockResolvedValue(deviceRow() as never);
    vi.mocked(repository.revokeDevice).mockResolvedValue(
      deviceRow({ revokedAt: new Date("2026-08-20T11:00:00Z"), revokedBy: userId }) as never,
    );

    const result = await revokeDevice(tenantId, deviceId, userId);

    expect(repository.revokeDevice).toHaveBeenCalledWith(deviceId, userId);
    expect(result.revoked_at).toBe("2026-08-20T11:00:00.000Z");
    expect(result.revoked_by).toBe(userId);
  });

  it("is idempotent on an already-revoked device — returns the existing state, never re-revokes", async () => {
    const alreadyRevoked = deviceRow({
      revokedAt: new Date("2026-08-20T08:00:00Z"),
      revokedBy: "99999999-9999-4999-8999-999999999999",
    });
    vi.mocked(repository.findByIdForTenant).mockResolvedValue(alreadyRevoked as never);

    const result = await revokeDevice(tenantId, deviceId, userId);

    expect(repository.revokeDevice).not.toHaveBeenCalled();
    expect(result.revoked_by).toBe("99999999-9999-4999-8999-999999999999");
  });
});

describe("assertDeviceUsable", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("throws DEVICE_REVOKED when no device id is presented at all", async () => {
    await expect(assertDeviceUsable(userId, null)).rejects.toMatchObject({
      status: 401,
      code: "DEVICE_REVOKED",
    });
    expect(repository.findByUserAndClientDeviceId).not.toHaveBeenCalled();
  });

  it("throws DEVICE_REVOKED when no matching device is registered", async () => {
    vi.mocked(repository.findByUserAndClientDeviceId).mockResolvedValue(null);

    await expect(assertDeviceUsable(userId, clientDeviceId)).rejects.toMatchObject({
      status: 401,
      code: "DEVICE_REVOKED",
    });
  });

  it("throws DEVICE_REVOKED when the matching device has been revoked", async () => {
    vi.mocked(repository.findByUserAndClientDeviceId).mockResolvedValue(
      deviceRow({ revokedAt: new Date("2026-08-20T08:00:00Z") }) as never,
    );

    await expect(assertDeviceUsable(userId, clientDeviceId)).rejects.toMatchObject({
      status: 401,
      code: "DEVICE_REVOKED",
    });
  });

  it("resolves without throwing for a registered, non-revoked device", async () => {
    vi.mocked(repository.findByUserAndClientDeviceId).mockResolvedValue(deviceRow() as never);

    await expect(assertDeviceUsable(userId, clientDeviceId)).resolves.toBeUndefined();
  });
});
