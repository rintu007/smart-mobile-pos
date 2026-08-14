import { describe, expect, it, vi, beforeEach } from "vitest";
import { Prisma } from "@prisma/client";
import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import { onboard } from "./service";
import type { OnboardingRequest } from "./schema";

vi.mock("./repository");

const authUserId = "11111111-1111-4111-8111-111111111111";

const input: OnboardingRequest = {
  tenant_id: "22222222-2222-4222-8222-222222222222",
  store_id: "33333333-3333-4333-8333-333333333333",
  user_id: "44444444-4444-4444-8444-444444444444",
  tenant_name: "Test Tenant",
  store_name: "Test Store",
  display_name: "Test Owner",
};

describe("onboard", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("creates a tenant, store, and user when this identity has never onboarded", async () => {
    vi.mocked(repository.findUserByAuthId).mockResolvedValue(null);
    const tenant = {};
    const store = {};
    const user = {};
    const ownerRole = {};
    // shopSettings (Sprint 25) is deliberately excluded from the assertion below: onboard()
    // destructures repository.createOnboarding's result rather than returning it whole, since its
    // BIGINT columns can't survive NextResponse.json's JSON.stringify (found live, identity.md's
    // Sprint 25 changelog entry) — this endpoint's response shape stays exactly what it already was.
    const shopSettings = { discountAutoApprovalThresholdMinorUnits: BigInt(50000) };
    vi.mocked(repository.createOnboarding).mockResolvedValue(
      { tenant, store, user, ownerRole, shopSettings } as never,
    );

    const result = await onboard(authUserId, input);

    expect(repository.createOnboarding).toHaveBeenCalledWith({ ...input, authUserId });
    expect(result).toEqual({ tenant, store, user, ownerRole });
  });

  it("is idempotent: a retry with the same generated ids does not throw", async () => {
    // The existing row's id matches input.user_id -- this is a retry, not a second attempt.
    vi.mocked(repository.findUserByAuthId).mockResolvedValue({
      id: input.user_id,
    } as never);
    const tenant = {};
    const store = {};
    const user = {};
    const ownerRole = {};
    const shopSettings = { discountAutoApprovalThresholdMinorUnits: BigInt(50000) };
    vi.mocked(repository.createOnboarding).mockResolvedValue(
      { tenant, store, user, ownerRole, shopSettings } as never,
    );

    const result = await onboard(authUserId, input);

    expect(result).toEqual({ tenant, store, user, ownerRole });
  });

  it("rejects a second distinct attempt from an already-onboarded identity", async () => {
    // Existing row's id does NOT match input.user_id -- a different generated attempt.
    vi.mocked(repository.findUserByAuthId).mockResolvedValue({
      id: "99999999-9999-4999-8999-999999999999",
    } as never);

    await expect(onboard(authUserId, input)).rejects.toMatchObject({
      status: 409,
      code: "ALREADY_ONBOARDED",
    });
    expect(repository.createOnboarding).not.toHaveBeenCalled();
  });

  it("translates a concurrent unique-constraint race on auth_user_id into ALREADY_ONBOARDED", async () => {
    vi.mocked(repository.findUserByAuthId).mockResolvedValue(null);
    vi.mocked(repository.createOnboarding).mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError("Unique constraint failed", {
        code: "P2002",
        clientVersion: "test",
        meta: { target: ["auth_user_id"] },
      }),
    );

    await expect(onboard(authUserId, input)).rejects.toMatchObject({
      status: 409,
      code: "ALREADY_ONBOARDED",
    });
  });

  it("re-throws an unrelated database error unchanged", async () => {
    vi.mocked(repository.findUserByAuthId).mockResolvedValue(null);
    const dbError = new Error("connection reset");
    vi.mocked(repository.createOnboarding).mockRejectedValue(dbError);

    await expect(onboard(authUserId, input)).rejects.toBe(dbError);
  });
});

describe("onboard error shape", () => {
  it("ALREADY_ONBOARDED is a real ApiError with the documented status/code", async () => {
    vi.mocked(repository.findUserByAuthId).mockResolvedValue({
      id: "99999999-9999-4999-8999-999999999999",
    } as never);

    try {
      await onboard(authUserId, input);
      expect.unreachable("onboard should have thrown");
    } catch (error) {
      expect(error).toBeInstanceOf(ApiError);
    }
  });
});
