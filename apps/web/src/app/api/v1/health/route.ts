import { NextResponse } from "next/server";

// A liveness check — infrastructure verification, not a documented V1 product route
// (docs/11-api/openapi.yaml). Exists so Sprint 01's CI pipeline and the eventual Vercel
// deployment have something concrete to build and respond with before any real endpoint exists.

export function GET() {
  return NextResponse.json({ status: "ok" });
}
