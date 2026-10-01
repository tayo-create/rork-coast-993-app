import { DurableObject } from "cloudflare:workers";

// Shape mirrors the iOS app's RewardsState (Swift JSONEncoder defaults:
// UUIDs as strings, Dates as seconds since 2001-01-01).
type Activity = { id: string; title: string; points: number; date: number; dedupeKey?: string | null };
type Claim = { id: string; rewardName: string; cost: number; code: string; date: number };
export type RewardsState = {
  points: number;
  activity: Activity[];
  claims: Claim[];
  listenDay: string;
  listenSecondsToday: number;
  lastDailyListenAwardDay: string;
  lastMusicTestAwardDay: string;
  enteredContestIDs: string[];
};

const MAX_ACTIVITY = 50;
const MAX_AWARD = 100;
const MAX_OPENING_BALANCE = 25_000;

function emptyState(): RewardsState {
  return {
    points: 0,
    activity: [],
    claims: [],
    listenDay: "",
    listenSecondsToday: 0,
    lastDailyListenAwardDay: "",
    lastMusicTestAwardDay: "",
    enteredContestIDs: [],
  };
}

function maxString(a: string, b: string): string {
  return (a ?? "") > (b ?? "") ? a ?? "" : b ?? "";
}

function sanitize(input: Partial<RewardsState>): RewardsState {
  const activity = Array.isArray(input.activity) ? input.activity.slice(0, 200) : [];
  return {
    points: Number.isFinite(input.points) ? Math.max(0, Math.floor(input.points as number)) : 0,
    activity: activity
      .filter((a) => a && typeof a.id === "string" && Number.isFinite(a.points))
      .map((a) => ({
        id: a.id,
        title: String(a.title ?? "").slice(0, 120),
        points: Math.min(Math.floor(a.points), MAX_AWARD),
        date: Number(a.date) || 0,
        dedupeKey: a.dedupeKey ?? null,
      })),
    claims: (Array.isArray(input.claims) ? input.claims.slice(0, 100) : []).filter(
      (c) => c && typeof c.id === "string",
    ),
    listenDay: String(input.listenDay ?? ""),
    listenSecondsToday: Math.max(0, Number(input.listenSecondsToday) || 0),
    lastDailyListenAwardDay: String(input.lastDailyListenAwardDay ?? ""),
    lastMusicTestAwardDay: String(input.lastMusicTestAwardDay ?? ""),
    enteredContestIDs: (Array.isArray(input.enteredContestIDs) ? input.enteredContestIDs : [])
      .map(String)
      .slice(0, 500),
  };
}

/** One instance per signed-in user (keyed by Rork user id). Owns that user's points ledger. */
export class RewardsAccount extends DurableObject {
  constructor(ctx: DurableObjectState, env: unknown) {
    super(ctx, env);
    this.ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS seen (key TEXT PRIMARY KEY)");
  }

  override async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/state") {
      const rewards = (await this.ctx.storage.get<RewardsState>("state")) ?? null;
      const profile = await this.touchProfile(request);
      return Response.json({ profile, rewards });
    }

    if (request.method === "POST" && url.pathname === "/sync") {
      const incoming = sanitize((await request.json()) as Partial<RewardsState>);
      const current = (await this.ctx.storage.get<RewardsState>("state")) ?? null;
      const merged = this.merge(current, incoming);
      await this.ctx.storage.put("state", merged);
      await this.touchProfile(request);
      return Response.json({ rewards: merged, syncedAt: Date.now() });
    }

    if (request.method === "POST" && url.pathname === "/delete") {
      await this.ctx.storage.deleteAll();
      return Response.json({ ok: true });
    }

    return new Response("not found", { status: 404 });
  }

  private async touchProfile(request: Request) {
    const email = request.headers.get("X-Coast-User-Email");
    const name = request.headers.get("X-Coast-User-Name");
    const existing = (await this.ctx.storage.get<{ email: string | null; name: string | null; createdAt: number }>(
      "profile",
    )) ?? { email: null, name: null, createdAt: Date.now() };
    const profile = { email: email ?? existing.email, name: name ?? existing.name, createdAt: existing.createdAt };
    await this.ctx.storage.put("profile", profile);
    return profile;
  }

  private isSeen(key: string): boolean {
    return this.ctx.storage.sql.exec("SELECT 1 FROM seen WHERE key = ?", key).toArray().length > 0;
  }

  private markSeen(key: string): void {
    this.ctx.storage.sql.exec("INSERT OR IGNORE INTO seen (key) VALUES (?)", key);
  }

  /**
   * Union-merge a device's state into the account. Every ledger entry is applied
   * at most once (by id), daily/one-time awards at most once (by dedupeKey), and
   * redemptions only if the account can afford them — so syncing is idempotent
   * across retries and multiple devices.
   */
  private merge(current: RewardsState | null, incoming: RewardsState): RewardsState {
    const base = current ?? emptyState();
    let points = base.points;
    const accepted: Activity[] = [];

    if (current === null) {
      // Brand-new account: the device's balance becomes the opening balance.
      points = Math.min(incoming.points, MAX_OPENING_BALANCE);
      for (const a of incoming.activity) {
        this.markSeen(`id:${a.id}`);
        if (a.dedupeKey) this.markSeen(`key:${a.dedupeKey}`);
        accepted.push(a);
      }
    } else {
      const fresh = incoming.activity.filter((a) => !this.isSeen(`id:${a.id}`)).sort((x, y) => x.date - y.date);
      for (const a of fresh) {
        if (a.dedupeKey && this.isSeen(`key:${a.dedupeKey}`)) {
          this.markSeen(`id:${a.id}`);
          continue;
        }
        if (a.points < 0 && points + a.points < 0) continue;
        points += a.points;
        this.markSeen(`id:${a.id}`);
        if (a.dedupeKey) this.markSeen(`key:${a.dedupeKey}`);
        accepted.push(a);
      }
    }

    const activityById = new Map<string, Activity>();
    for (const a of [...accepted, ...base.activity]) activityById.set(a.id, a);
    const activity = [...activityById.values()].sort((x, y) => y.date - x.date).slice(0, MAX_ACTIVITY);

    const claimsById = new Map<string, Claim>();
    for (const c of base.claims) claimsById.set(c.id, c);
    for (const c of incoming.claims) {
      if (claimsById.has(c.id)) continue;
      if (current === null || this.isSeen(`key:redeem:${c.id}`)) claimsById.set(c.id, c);
    }
    const claims = [...claimsById.values()].sort((x, y) => y.date - x.date);

    let listenDay = base.listenDay;
    let listenSecondsToday = base.listenSecondsToday;
    if (incoming.listenDay > listenDay) {
      listenDay = incoming.listenDay;
      listenSecondsToday = incoming.listenSecondsToday;
    } else if (incoming.listenDay === listenDay) {
      listenSecondsToday = Math.max(listenSecondsToday, incoming.listenSecondsToday);
    }

    return {
      points: Math.max(0, points),
      activity,
      claims,
      listenDay,
      listenSecondsToday,
      lastDailyListenAwardDay: maxString(base.lastDailyListenAwardDay, incoming.lastDailyListenAwardDay),
      lastMusicTestAwardDay: maxString(base.lastMusicTestAwardDay, incoming.lastMusicTestAwardDay),
      enteredContestIDs: [...new Set([...base.enteredContestIDs, ...incoming.enteredContestIDs])],
    };
  }
}
