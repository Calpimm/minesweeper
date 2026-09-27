import { LEVELS, isLevel, replay, type LevelName } from "./game";
import { compareVersions } from "./semver";

export interface Env {
  DB: D1Database;
  /** Oldest app version allowed to play ranked games, e.g. "1.1.0". */
  MIN_CLIENT_VERSION: string;
}

/** Slack between the server's wall clock and the client's game clock. */
const CLOCK_TOLERANCE_MS = 2_000;
const MAX_GAMES_PER_MINUTE = 30;
const OPEN_GAME_TTL_MS = 24 * 60 * 60 * 1000;

class HttpError extends Error {
  constructor(readonly status: number, readonly code: string, message: string) {
    super(message);
  }
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await route(request, env);
    } catch (error) {
      if (error instanceof HttpError) return json({ error: error.code, message: error.message }, error.status);
      console.error(error);
      return json({ error: "internal", message: "Something went wrong." }, 500);
    }
  },

  /** Daily clean-up of games that were started but never finished. */
  async scheduled(_controller: ScheduledController, env: Env): Promise<void> {
    await env.DB.prepare("DELETE FROM games WHERE status = 'open' AND issued_at < ?")
      .bind(Date.now() - OPEN_GAME_TTL_MS)
      .run();
  },
} satisfies ExportedHandler<Env>;

async function route(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "");
  const method = request.method;

  if (method === "GET" && path === "/v1/health") {
    return json({ ok: true, minClientVersion: env.MIN_CLIENT_VERSION });
  }
  if (method === "GET" && path.startsWith("/v1/leaderboard/")) {
    return leaderboard(request, env, path.slice("/v1/leaderboard/".length), url);
  }

  requireSupportedClient(request, env);
  if (method === "POST" && path === "/v1/players") return createPlayer(request, env);
  if (method === "PATCH" && path === "/v1/players/me") return renamePlayer(request, env);
  if (method === "POST" && path === "/v1/games") return startGame(request, env);
  const finish = path.match(/^\/v1\/games\/([0-9a-f-]{36})\/finish$/);
  if (method === "POST" && finish) return finishGame(request, env, finish[1]);

  throw new HttpError(404, "not_found", "No such endpoint.");
}

// MARK: - Players

async function createPlayer(request: Request, env: Env): Promise<Response> {
  const name = validName((await body(request)).name);
  const id = crypto.randomUUID();
  const token = randomToken();
  try {
    await env.DB.prepare("INSERT INTO players (id, name, token_hash, created_at) VALUES (?, ?, ?, ?)")
      .bind(id, name, await sha256(token), Date.now())
      .run();
  } catch (error) {
    if (String(error).includes("UNIQUE")) throw new HttpError(409, "name_taken", "That name is already taken.");
    throw error;
  }
  return json({ id, name, token }, 201);
}

async function renamePlayer(request: Request, env: Env): Promise<Response> {
  const player = await authenticate(request, env);
  const name = validName((await body(request)).name);
  try {
    await env.DB.prepare("UPDATE players SET name = ? WHERE id = ?").bind(name, player.id).run();
  } catch (error) {
    if (String(error).includes("UNIQUE")) throw new HttpError(409, "name_taken", "That name is already taken.");
    throw error;
  }
  return json({ id: player.id, name });
}

// MARK: - Games

async function startGame(request: Request, env: Env): Promise<Response> {
  const player = await authenticate(request, env);
  const level = (await body(request)).level;
  if (!isLevel(level)) throw new HttpError(400, "invalid_level", "Only Beginner, Intermediate and Expert are ranked.");

  const recent = await env.DB.prepare("SELECT COUNT(*) AS n FROM games WHERE player_id = ? AND issued_at > ?")
    .bind(player.id, Date.now() - 60_000)
    .first<{ n: number }>();
  if ((recent?.n ?? 0) >= MAX_GAMES_PER_MINUTE) throw new HttpError(429, "slow_down", "Too many games; try again in a minute.");

  const id = crypto.randomUUID();
  const seed = crypto.getRandomValues(new Uint32Array(1))[0];
  await env.DB.prepare("INSERT INTO games (id, player_id, level, seed, issued_at) VALUES (?, ?, ?, ?, ?)")
    .bind(id, player.id, level, seed, Date.now())
    .run();
  return json({ id, level, seed }, 201);
}

async function finishGame(request: Request, env: Env, gameId: string): Promise<Response> {
  const player = await authenticate(request, env);
  const game = await env.DB.prepare("SELECT level, seed, issued_at, status FROM games WHERE id = ? AND player_id = ?")
    .bind(gameId, player.id)
    .first<{ level: LevelName; seed: number; issued_at: number; status: string }>();
  if (!game) throw new HttpError(404, "not_found", "Unknown game.");
  if (game.status !== "open") throw new HttpError(409, "already_finished", "This game was already submitted.");

  const now = Date.now();
  const result = replay(LEVELS[game.level], game.seed, (await body(request)).moves);
  const reason = !result.ok
    ? result.reason
    : result.timeMs > now - game.issued_at + CLOCK_TOLERANCE_MS
      ? "time does not match the server clock"
      : null;
  if (reason || !result.ok) {
    await env.DB.prepare("UPDATE games SET status = 'rejected', finished_at = ? WHERE id = ?").bind(now, gameId).run();
    throw new HttpError(422, "invalid_game", `Game rejected: ${reason}.`);
  }

  const timeMs = result.timeMs;
  const [, upsert] = await env.DB.batch([
    env.DB.prepare("UPDATE games SET status = 'won', finished_at = ?, time_ms = ? WHERE id = ?").bind(now, timeMs, gameId),
    env.DB.prepare(
      `INSERT INTO best_times (player_id, level, time_ms, game_id, achieved_at) VALUES (?, ?, ?, ?, ?)
       ON CONFLICT (player_id, level) DO UPDATE
         SET time_ms = excluded.time_ms, game_id = excluded.game_id, achieved_at = excluded.achieved_at
         WHERE excluded.time_ms < best_times.time_ms`,
    ).bind(player.id, game.level, timeMs, gameId, now),
  ]);

  return json({
    timeMs,
    personalBest: (upsert.meta.changes ?? 0) > 0,
    best: await personalBest(env, player.id, game.level),
  });
}

// MARK: - Leaderboard

async function leaderboard(request: Request, env: Env, level: string, url: URL): Promise<Response> {
  if (!isLevel(level)) throw new HttpError(404, "invalid_level", "Unknown level.");
  const limit = Math.min(Math.max(Number(url.searchParams.get("limit")) || 50, 1), 100);
  const { results } = await env.DB.prepare(
    `SELECT p.name, b.time_ms, b.achieved_at FROM best_times b JOIN players p ON p.id = b.player_id
     WHERE b.level = ? ORDER BY b.time_ms, b.achieved_at LIMIT ?`,
  )
    .bind(level, limit)
    .all<{ name: string; time_ms: number; achieved_at: number }>();

  const player = request.headers.has("authorization") ? await authenticate(request, env).catch(() => null) : null;
  return json({
    level,
    entries: results.map((r, index) => ({ rank: index + 1, name: r.name, timeMs: r.time_ms, achievedAt: r.achieved_at })),
    me: player ? await personalBest(env, player.id, level) : null,
  });
}

async function personalBest(env: Env, playerId: string, level: LevelName) {
  const best = await env.DB.prepare("SELECT time_ms, achieved_at FROM best_times WHERE player_id = ? AND level = ?")
    .bind(playerId, level)
    .first<{ time_ms: number; achieved_at: number }>();
  if (!best) return null;
  const ahead = await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM best_times WHERE level = ? AND (time_ms < ? OR (time_ms = ? AND achieved_at < ?))",
  )
    .bind(level, best.time_ms, best.time_ms, best.achieved_at)
    .first<{ n: number }>();
  return { rank: (ahead?.n ?? 0) + 1, timeMs: best.time_ms, achievedAt: best.achieved_at };
}

// MARK: - Helpers

function requireSupportedClient(request: Request, env: Env) {
  const version = request.headers.get("x-client-version");
  if (!version || compareVersions(version, env.MIN_CLIENT_VERSION) < 0) {
    throw new HttpError(426, "upgrade_required", `Please update Minesweeper to ${env.MIN_CLIENT_VERSION} or later to play online.`);
  }
}

async function authenticate(request: Request, env: Env): Promise<{ id: string; name: string }> {
  const token = request.headers.get("authorization")?.match(/^Bearer (\S+)$/)?.[1];
  const player = token
    ? await env.DB.prepare("SELECT id, name FROM players WHERE token_hash = ?").bind(await sha256(token)).first<{ id: string; name: string }>()
    : null;
  if (!player) throw new HttpError(401, "unauthorized", "Unknown player.");
  return player;
}

async function body(request: Request): Promise<Record<string, unknown>> {
  if (Number(request.headers.get("content-length") ?? 0) > 256 * 1024) {
    throw new HttpError(413, "too_large", "Request body is too large.");
  }
  try {
    const value = await request.json();
    if (typeof value === "object" && value !== null) return value as Record<string, unknown>;
  } catch {}
  throw new HttpError(400, "bad_json", "Expected a JSON object.");
}

function validName(value: unknown): string {
  const name = typeof value === "string" ? value.trim().replace(/\s+/g, " ") : "";
  if (!/^[\p{L}\p{N} _.-]{2,20}$/u.test(name)) {
    throw new HttpError(400, "invalid_name", "Names are 2–20 letters, digits, spaces, dots, dashes or underscores.");
  }
  return name;
}

function randomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
