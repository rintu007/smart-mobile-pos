import { vi } from "vitest";

// core/auth/admin-client.ts constructs a real Supabase client at module-load time
// (createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, ...)), which throws in the test
// environment (no Supabase env vars set). Every module in the roles/service.ts -> admin-client.ts
// chain -- and, since Sprint 27, pos/service.ts too (it now imports roles/service.ts for the
// discount-approval check) -- transitively hits this at import time, including under an
// auto-mocked `vi.mock("path")` with no factory, which still evaluates the real module once to
// derive its shape. Mocked globally here rather than per-test-file, since any future module can
// join this chain the same way pos/service.ts just did -- found live when Sprint 27's discount
// work broke two unrelated test files (sales-invoices, sync) that had never needed this mock
// before.
vi.mock("@/core/auth/admin-client", () => ({
  supabaseAdmin: { auth: { admin: {} } },
}));
