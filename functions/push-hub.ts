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
const SUBMISSION_PATTERN = /^[0-9a-f-]{16,64}$/i;
const FEELINGS = new Set(["love", "like", "ok", "dislike", "never"]);
const FAMILIARITY = new Set(["veryWell", "know", "heard", "dontKnow"]);
const FREQUENCY = new Set(["aLot", "sometimes", "aLittle", "rarely", "never"]);

type MusicTestAnswerInput = {
  songId?: number;
  artist?: string;
  title?: string;
  feeling?: string;
  familiarity?: string;
  frequency?: string;
};

type MusicTestRow = {
  song_id: number;
  artist: string;
  title: string;
  votes: number;
  love: number;
  liked: number;
  ok: number;
  disliked: number;
  never_play: number;
  familiar: number;
  play_more: number;
};

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
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS music_test_responses (
        submission_id TEXT NOT NULL,
        test_id TEXT NOT NULL,
        song_id INTEGER NOT NULL,
        artist TEXT NOT NULL,
        title TEXT NOT NULL,
        feeling TEXT NOT NULL,
        familiarity TEXT NOT NULL,
        frequency TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (submission_id, test_id, song_id)
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

    if (request.method === "POST" && url.pathname === "/music-test") {
      return this.saveMusicTest(await request.json());
    }

    if (request.method === "GET" && url.pathname === "/music-test/results") {
      return Response.json(this.musicTestResults());
    }

    if (request.method === "GET" && url.pathname === "/stats") {
      const devices = this.ctx.storage.sql
        .exec<{ total: number; alerts: number }>(
          `SELECT COUNT(*) AS total, COALESCE(SUM(alerts), 0) AS alerts FROM devices`,
        )
        .one();
      const takers = this.ctx.storage.sql
        .exec<{ takers: number }>("SELECT COUNT(DISTINCT submission_id) AS takers FROM music_test_responses")
        .one();
      return Response.json({
        devices: { ...devices, testTakers: takers.takers },
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

  /** Upserts anonymous Music Test answers (one row per submission + song). */
  private saveMusicTest(raw: unknown): Response {
    const body = (raw ?? {}) as { submissionId?: string; testId?: string; answers?: MusicTestAnswerInput[] };
    const submissionId = (body.submissionId ?? "").trim();
    const testId = (body.testId ?? "").trim().slice(0, 40);
    if (!SUBMISSION_PATTERN.test(submissionId) || !testId) {
      return Response.json({ error: "Invalid submission" }, { status: 400 });
    }
    const answers = Array.isArray(body.answers) ? body.answers.slice(0, 20) : [];
    let saved = 0;
    for (const answer of answers) {
      const songId = Number(answer.songId);
      if (!Number.isInteger(songId) || songId <= 0) continue;
      if (!FEELINGS.has(answer.feeling ?? "") || !FAMILIARITY.has(answer.familiarity ?? "") || !FREQUENCY.has(answer.frequency ?? "")) continue;
      this.ctx.storage.sql.exec(
        `INSERT INTO music_test_responses
           (submission_id, test_id, song_id, artist, title, feeling, familiarity, frequency, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(submission_id, test_id, song_id) DO UPDATE SET
           feeling = excluded.feeling,
           familiarity = excluded.familiarity,
           frequency = excluded.frequency,
           updated_at = excluded.updated_at`,
        submissionId,
        testId,
        songId,
        String(answer.artist ?? "").slice(0, 120),
        String(answer.title ?? "").slice(0, 160),
        answer.feeling,
        answer.familiarity,
        answer.frequency,
        Date.now(),
      );
      saved += 1;
    }
    if (saved === 0) return Response.json({ error: "No valid answers" }, { status: 400 });
    return Response.json({ ok: true, saved });
  }

  private musicTestResults() {
    const rows = this.ctx.storage.sql
      .exec<MusicTestRow>(
        `SELECT song_id, MAX(artist) AS artist, MAX(title) AS title, COUNT(*) AS votes,
                SUM(feeling = 'love') AS love, SUM(feeling = 'like') AS liked, SUM(feeling = 'ok') AS ok,
                SUM(feeling = 'dislike') AS disliked, SUM(feeling = 'never') AS never_play,
                SUM(familiarity IN ('veryWell', 'know')) AS familiar,
                SUM(frequency IN ('aLot', 'sometimes')) AS play_more
         FROM music_test_responses
         GROUP BY song_id`,
      )
      .toArray();
    const songs = rows
      .map((r) => {
        const votes = Math.max(r.votes, 1);
        const score = (r.love * 5 + r.liked * 4 + r.ok * 3 + r.disliked * 2 + r.never_play) / votes;
        return {
          songId: r.song_id,
          artist: r.artist,
          title: r.title,
          votes: r.votes,
          score: Math.round(score * 10) / 10,
          positivePct: Math.round(((r.love + r.liked) / votes) * 100),
          familiarPct: Math.round((r.familiar / votes) * 100),
          playMorePct: Math.round((r.play_more / votes) * 100),
        };
      })
      .sort((a, b) => b.score - a.score || b.votes - a.votes);
    return { songs };
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
