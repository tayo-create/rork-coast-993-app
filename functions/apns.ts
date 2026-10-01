// Apple Push Notification service client for Cloudflare Workers.
// Token-based auth (ES256 JWT signed with the .p8 key) over HTTP/2, which
// Cloudflare's egress negotiates automatically for api.push.apple.com.

export type ApnsEnv = {
  APNS_KEY_ID?: string;
  APNS_TEAM_ID?: string;
  APNS_PRIVATE_KEY?: string;
  APNS_BUNDLE_ID?: string;
};

export type PushEnvironment = "sandbox" | "production";

export type ApnsResult = {
  ok: boolean;
  status: number;
  reason?: string;
  environment: PushEnvironment;
};

const DEFAULT_BUNDLE_ID = "app.rork.3yg97ylru9najufvpglu9";

let cachedJwt: { token: string; issuedAt: number; keyId: string } | null = null;
let cachedKey: { pem: string; key: CryptoKey } | null = null;

export function apnsConfigured(env: ApnsEnv): boolean {
  return Boolean(env.APNS_KEY_ID && env.APNS_TEAM_ID && env.APNS_PRIVATE_KEY);
}

export function bundleId(env: ApnsEnv): string {
  return env.APNS_BUNDLE_ID?.trim() || DEFAULT_BUNDLE_ID;
}

function base64UrlEncode(input: ArrayBuffer | Uint8Array | string): string {
  const bytes =
    typeof input === "string"
      ? new TextEncoder().encode(input)
      : input instanceof Uint8Array
        ? input
        : new Uint8Array(input);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function signingKey(pemRaw: string): Promise<CryptoKey> {
  if (cachedKey && cachedKey.pem === pemRaw) return cachedKey.key;
  // Env values pasted from a .p8 file sometimes arrive with literal "\n" escapes.
  const pem = pemRaw.replace(/\\n/g, "\n");
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  cachedKey = { pem: pemRaw, key };
  return key;
}

async function providerToken(env: ApnsEnv): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const keyId = env.APNS_KEY_ID ?? "";
  // Apple accepts a provider token for up to 60 minutes; refresh at 50.
  if (cachedJwt && cachedJwt.keyId === keyId && now - cachedJwt.issuedAt < 50 * 60) {
    return cachedJwt.token;
  }
  const header = base64UrlEncode(JSON.stringify({ alg: "ES256", kid: keyId }));
  const claims = base64UrlEncode(JSON.stringify({ iss: env.APNS_TEAM_ID, iat: now }));
  const unsigned = `${header}.${claims}`;
  const key = await signingKey(env.APNS_PRIVATE_KEY ?? "");
  // WebCrypto returns the raw r||s (IEEE P1363) signature JWT expects.
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(unsigned),
  );
  const token = `${unsigned}.${base64UrlEncode(signature)}`;
  cachedJwt = { token, issuedAt: now, keyId };
  return token;
}

async function sendOnce(
  env: ApnsEnv,
  deviceToken: string,
  environment: PushEnvironment,
  payload: unknown,
  collapseId?: string,
): Promise<ApnsResult> {
  const host = environment === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
  const headers: Record<string, string> = {
    authorization: `bearer ${await providerToken(env)}`,
    "apns-topic": bundleId(env),
    "apns-push-type": "alert",
    "apns-priority": "10",
    "apns-expiration": String(Math.floor(Date.now() / 1000) + 60 * 30),
    "content-type": "application/json",
  };
  if (collapseId) headers["apns-collapse-id"] = collapseId.slice(0, 64);

  const response = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers,
    body: JSON.stringify(payload),
  });
  if (response.ok) return { ok: true, status: response.status, environment };
  let reason: string | undefined;
  try {
    reason = ((await response.json()) as { reason?: string }).reason;
  } catch {
    reason = undefined;
  }
  return { ok: false, status: response.status, reason, environment };
}

/**
 * Sends an alert push. If Apple rejects the token for the stated environment
 * (dev vs. TestFlight/App Store builds), retries once against the other one.
 */
export async function sendPush(
  env: ApnsEnv,
  deviceToken: string,
  environment: PushEnvironment,
  payload: unknown,
  collapseId?: string,
): Promise<ApnsResult> {
  const first = await sendOnce(env, deviceToken, environment, payload, collapseId);
  if (first.ok || first.reason !== "BadDeviceToken") return first;
  const other: PushEnvironment = environment === "production" ? "sandbox" : "production";
  return sendOnce(env, deviceToken, other, payload, collapseId);
}

/** True when Apple says the token will never work again and should be dropped. */
export function isDeadToken(result: ApnsResult): boolean {
  return (
    result.status === 410 ||
    result.reason === "Unregistered" ||
    result.reason === "BadDeviceToken" ||
    result.reason === "DeviceTokenNotForTopic"
  );
}
