// Coast 99.3 backend: synced Coast Rewards accounts + contest keyword push alerts.
import { adminPage } from "./admin-page";
import type { ApnsEnv } from "./apns";

export { PushHub } from "./push-hub";
export { RewardsAccount } from "./rewards-account";

type Env = ApnsEnv & {
  DO: Fetcher;
  COAST_ADMIN_KEY?: string;
};

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Admin-Key",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

async function toDO(
  env: Env,
  className: "PushHub" | "RewardsAccount",
  id: string,
  path: string,
  init: { method: string; body?: string; headers?: Record<string, string> },
): Promise<Response> {
  const request = new Request(`https://internal${path}`, {
    method: init.method,
    body: init.body,
    headers: {
      "Content-Type": "application/json",
      "X-Rork-DO-Class": className,
      "X-Rork-DO-Id": id,
      ...(init.headers ?? {}),
    },
  });
  const response = await env.DO.fetch(request);
  return new Response(response.body, {
    status: response.status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

function identityHeaders(request: Request, userId: string | null): Record<string, string> {
  const headers: Record<string, string> = {};
  if (userId) headers["X-Coast-User-Id"] = userId;
  const email = request.headers.get("X-Rork-User-Email");
  const name = request.headers.get("X-Rork-User-Name");
  if (email) headers["X-Coast-User-Email"] = email;
  if (name) headers["X-Coast-User-Name"] = name;
  return headers;
}

function isAdmin(request: Request, env: Env): boolean {
  const expected = env.COAST_ADMIN_KEY?.trim();
  if (!expected) return false;
  const provided = request.headers.get("X-Admin-Key")?.trim() ?? "";
  if (provided.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ provided.charCodeAt(i);
  return diff === 0;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });

    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";
    // Stamped by the platform only when a valid Rork Auth bearer token was sent.
    const userId = request.headers.get("X-Rork-User-Id");

    try {
      // ---- Public ----
      if (path === "/ping") return json({ ok: true, now: new Date().toISOString() });

      if (path === "/keywords" && request.method === "GET") {
        return toDO(env, "PushHub", "global", "/keywords", { method: "GET" });
      }

      // ---- Push device registration (guest or signed in) ----
      if (path === "/push/register" && request.method === "POST") {
        return toDO(env, "PushHub", "global", "/register", {
          method: "POST",
          body: await request.text(),
          headers: identityHeaders(request, userId),
        });
      }
      if (path === "/push/unregister" && request.method === "POST") {
        return toDO(env, "PushHub", "global", "/unregister", { method: "POST", body: await request.text() });
      }

      // ---- Account (requires sign-in) ----
      if (path === "/me" || path === "/rewards/sync" || path === "/account") {
        if (!userId) return json({ error: "Please sign in again." }, 401);
        const headers = identityHeaders(request, userId);

        if (path === "/me" && request.method === "GET") {
          return toDO(env, "RewardsAccount", userId, "/state", { method: "GET", headers });
        }
        if (path === "/rewards/sync" && request.method === "POST") {
          return toDO(env, "RewardsAccount", userId, "/sync", {
            method: "POST",
            body: await request.text(),
            headers,
          });
        }
        if (path === "/account" && request.method === "DELETE") {
          await toDO(env, "PushHub", "global", "/unlink-user", { method: "POST", body: "{}", headers });
          return toDO(env, "RewardsAccount", userId, "/delete", { method: "POST", body: "{}", headers });
        }
      }

      // ---- Station admin: announce a keyword to every opted-in device ----
      if (path === "/admin" && request.method === "GET") {
        return new Response(adminPage, { headers: { "Content-Type": "text/html; charset=utf-8" } });
      }
      if (path.startsWith("/admin/")) {
        if (!env.COAST_ADMIN_KEY) return json({ error: "COAST_ADMIN_KEY is not configured on the backend." }, 503);
        if (!isAdmin(request, env)) return json({ error: "Wrong admin key." }, 401);

        if (path === "/admin/stats" && request.method === "GET") {
          return toDO(env, "PushHub", "global", "/stats", { method: "GET" });
        }
        if (path === "/admin/announce" && request.method === "POST") {
          return toDO(env, "PushHub", "global", "/announce", { method: "POST", body: await request.text() });
        }
      }

      return json({ error: "not found" }, 404);
    } catch (err) {
      console.error("request failed", path, err instanceof Error ? err.message : String(err));
      return json({ error: "Something went wrong. Please try again." }, 500);
    }
  },
} satisfies ExportedHandler<Env>;
