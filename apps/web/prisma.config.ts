import { config } from "dotenv";
import { defineConfig, env } from "prisma/config";

// Bare `dotenv/config` only loads `.env` — this project's own convention (.env.example's own
// instruction) is `.env.local`, which `next dev`/`next build` already load via Next's own env
// loader but the bare Prisma CLI never would otherwise. Confirmed live: `prisma generate` failed
// to resolve DIRECT_URL with a real .env.local present until this was made explicit.
config({ path: ".env.local", quiet: true });

// Prisma 7 moved connection-string configuration out of schema.prisma entirely (see the comment
// above the `datasource` block in prisma/schema.prisma). `url` here is used by the Prisma CLI for
// `migrate`/`db push` only — the direct (non-pooled) connection, per docs/11-api/rate-limiting.md
// §3's existing DATABASE_URL/DIRECT_URL split. The pooled connection PrismaClient itself uses at
// runtime is configured separately, in core/db/client.ts, via the `pg` driver adapter.
export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
  },
  datasource: {
    url: env("DIRECT_URL"),
  },
});
