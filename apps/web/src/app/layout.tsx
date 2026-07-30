import type { Metadata } from "next";

// Per docs/09-navigation/web-routes.md, apps/web has no marketing/product UI in V1 — its entire
// user-facing surface is the /verify fallback page (not yet built, a later sprint) and the API.
// This root layout exists only because Next.js's App Router requires one; it is not product scope.

export const metadata: Metadata = {
  title: "SmartPOS X",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
