import { DurableObject } from "cloudflare:workers";
import { apnsConfigured, isDeadToken, sendPush, type ApnsEnv, type PushEnvironment } from "./apns";

type Env = ApnsEnv & { DO: Fetcher };

type DeviceRow = { token: string; environment: string };

type KeywordRow = {
  id: string;
  keyword: string;
  contest_slug: string | null;
  contest_title: string | null;
  message: string | null;
  created_at: number;
  delivered: number;
  failed: number;
};

export type AnnounceInput = {
  keyword: string;
  contestSlug?: string;
  contestTitle?: string;
  message?: string;
};

const TOKEN_PATTERN = /^[0-9a-f]{64,200}$/i;

/** Singleton ("global") registry of device tokens + keyword announcements. */
export class PushHub extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS devices (
        token TEXT PRIMARY KEY,
        user_id TEXT,
        environment TEXT NOT NULL,
        alerts INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL
      )
    `);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS keywords (
        id TEXT PRIMARY KEY,
        keyword TEXT NOT NULL,
        contest_slug TEXT,
        contest_title TEXT,
        message TEXT,
        created_at INTEGER NOT NULL,
        delivered INTEGER NOT NULL DEFAULT 0,
        failed INTEGER NOT NULL DEFAULT 0
      )
    `);
  }

  override async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const userId = request.headers.get("X-Coast-User-Id");

    if (request.method === "POST" && url.pathname === "/register") {
      const body = (await request.json()) as {
        token?: string;
        environment?: string;
        alertsEnabled?: boolean;
      };
      const token = (body.token ?? "").trim();
      if (!TOKEN_PATTERN.test(token)) return Response.json({ error: "Invalid device token" }, { status: 400 });
      const environment: PushEnvironment = body.environment === "production" ? "production" : "sandbox";
      this.ctx.storage.sql.exec(
        `INSERT INTO devices (token, user_id, environment, alerts, updated_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(token) DO UPDATE SET
           user_id = excluded.user_id,
           environment = excluded.environment,
           alerts = excluded.alerts,
           updated_at = excluded.updated_at`,
        token,
        userId,
        environment,
        body.alertsEnabled === false ? 0 : 1,
        Date.now(),
      );
      return Response.json({ ok: true });
    }

    if (request.method === "POST" && url.pathname === "/unregister") {
      const body = (await request.json()) as { token?: string };
      this.ctx.storage.sql.exec("DELETE FROM devices WHERE token = ?", body.token ?? "");
      return Response.json({ ok: true });
    }

    if (request.method === "POST" && url.pathname === "/unlink-user") {
      if (userId) this.ctx.storage.sql.exec("UPDATE devices SET user_id = NULL WHERE user_id = ?", userId);
      return Response.json({ ok: true });
    }

    if (request.method === "GET" && url.pathname === "/keywords") {
      return Response.json({ keywords: this.recentKeywords(10) });
    }

    if (request.method === "GET" && url.pathname === "/stats") {
      const devices = this.ctx.storage.sql
        .exec<{ total: number; alerts: number; accounts: number }>(
          `SELECT COUNT(*) AS total,
                  COALESCE(SUM(alerts), 0) AS alerts,
                  COUNT(DISTINCT user_id) AS accounts
           FROM devices`,
        )
        .one();
      return Response.json({
        devices,
        apnsConfigured: apnsConfigured(this.env),
        keywords: this.recentKeywords(10),
      });
    }

    if (request.method === "POST" && url.pathname === "/announce") {
      const input = (await request.json()) as AnnounceInput;
      return Response.json(await this.announce(input));
    }

    return new Response("not found", { status: 404 });
  }

  private recentKeywords(limit: number) {
    return this.ctx.storage.sql
      .exec<KeywordRow>("SELECT * FROM keywords ORDER BY created_at DESC LIMIT ?", limit)
      .toArray()
      .map((row) => ({
        id: row.id,
        keyword: row.keyword,
        contestSlug: row.contest_slug,
        contestTitle: row.contest_title,
        message: row.message,
        createdAt: row.created_at,
        delivered: row.delivered,
        failed: row.failed,
      }));
  }

  private async announce(input: AnnounceInput) {
    const keyword = (input.keyword ?? "").trim().toUpperCase().slice(0, 40);
    if (!keyword) return { ok: false, error: "Keyword is required" };

    const id = crypto.randomUUID();
    const contestSlug = input.contestSlug?.trim() || "coast-cash-keyword";
    const contestTitle = input.contestTitle?.trim() || "Coast Cash Keyword";
    const message =
      input.message?.trim() || `The keyword is ${keyword}. Enter it now for your shot to win!`;

    this.ctx.storage.sql.exec(
      `INSERT INTO keywords (id, keyword, contest_slug, contest_title, message, created_at)
       VALUES (?, ?, ?, ?, ?, ?)`,
      id,
      keyword,
      contestSlug,
      contestTitle,
      message,
      Date.now(),
    );

    if (!apnsConfigured(this.env)) {
      console.warn("keyword saved but APNs credentials are not configured");
      return { ok: true, id, keyword, delivered: 0, failed: 0, removed: 0, apnsConfigured: false };
    }

    const devices = this.ctx.storage.sql
      .exec<DeviceRow>("SELECT token, environment FROM devices WHERE alerts = 1")
      .toArray();

    const payload = {
      aps: {
        alert: { title: `Keyword Alert · ${contestTitle}`, subtitle: `Keyword: ${keyword}`, body: message },
        sound: "default",
        "interruption-level": "time-sensitive",
        "relevance-score": 1,
        "thread-id": "keywords",
      },
      type: "keyword",
      announcementId: id,
      keyword,
      contestSlug,
      contestTitle,
    };

    let delivered = 0;
    let failed = 0;
    let removed = 0;
    const chunkSize = 25;
    for (let i = 0; i < devices.length; i += chunkSize) {
      const chunk = devices.slice(i, i + chunkSize);
      const results = await Promise.all(
        chunk.map(async (device) => {
          try {
            const env: PushEnvironment = device.environment === "production" ? "production" : "sandbox";
            return { device, result: await sendPush(this.env, device.token, env, payload, id) };
          } catch (err) {
            console.error("apns send threw", err instanceof Error ? err.message : String(err));
            return { device, result: null };
          }
        }),
      );
      for (const { device, result } of results) {
        if (result?.ok) {
          delivered += 1;
          if (result.environment !== device.environment) {
            this.ctx.storage.sql.exec(
              "UPDATE devices SET environment = ? WHERE token = ?",
              result.environment,
              device.token,
            );
          }
        } else {
          failed += 1;
          if (result && isDeadToken(result)) {
            this.ctx.storage.sql.exec("DELETE FROM devices WHERE token = ?", device.token);
            removed += 1;
          } else if (result) {
            console.warn("apns rejected", result.status, result.reason);
          }
        }
      }
    }

    this.ctx.storage.sql.exec(
      "UPDATE keywords SET delivered = ?, failed = ? WHERE id = ?",
      delivered,
      failed,
      id,
    );
    return { ok: true, id, keyword, delivered, failed, removed, apnsConfigured: true };
  }
}
