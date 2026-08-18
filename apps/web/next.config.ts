import type { NextConfig } from "next";

// Sprint 43 (backlog.md M4 item 8) — found while walking owasp-checklist.md's A05 row against the
// real build: no security headers were configured at all (this API has no browser-rendered pages
// of its own beyond the placeholder /404, but every response — including error JSON — still went
// out with Next's default `X-Powered-By` header and no explicit framing/content-type-sniffing
// protection). `poweredByHeader: false` and a minimal, safe header set added; no CSP here — this API
// serves no HTML/inline scripts of its own to have a meaningful policy over, and a wrong CSP guess
// is worse than none, per this project's own standing practice of not committing to unverified specifics.
const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Referrer-Policy", value: "no-referrer" },
        ],
      },
    ];
  },
};

export default nextConfig;
