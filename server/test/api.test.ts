import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { LEVELS, mineLayout, replay, type Move } from "../src/game";

const VERSION = { "x-client-version": "1.0.0", "content-type": "application/json" };

async function call(method: string, path: string, body?: unknown, token?: string) {
  const headers: Record<string, string> = { ...VERSION };
  if (token) headers.authorization = `Bearer ${token}`;
  const res = await SELF.fetch(`https://api.test${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined });
  return { status: res.status, body: (await res.json()) as any };
}

async function register(name: string) {
  const res = await call("POST", "/v1/players", { name });
  expect(res.status).toBe(201);
  return res.body as { id: string; name: string; token: string };
}

/** A legal winning move list for a beginner board with this seed. */
function solve(seed: number, step: number): Move[] {
  const mines = new Set(mineLayout(LEVELS.beginner, seed));
  const first = [...Array(81).keys()].find((i) => !mines.has(i))!;
  const kept: Move[] = [];
  for (const i of [first, ...Array(81).keys()]) {
    if (mines.has(i)) continue;
    const move: Move = { t: kept.length * step, a: "r", i };
    const attempt = replay(LEVELS.beginner, seed, [...kept, move]);
    if (attempt.ok || attempt.reason === "game was not won") kept.push(move);
  }
  return kept;
}

async function backdate(gameId: string, ms: number) {
  await env.DB.prepare("UPDATE games SET issued_at = issued_at - ? WHERE id = ?").bind(ms, gameId).run();
}

describe("players", () => {
  it("registers, rejects duplicates case-insensitively, renames", async () => {
    const p = await register("Alice");
    expect((await call("POST", "/v1/players", { name: "alice" })).status).toBe(409);
    expect((await call("POST", "/v1/players", { name: "x" })).status).toBe(400);
    const renamed = await call("PATCH", "/v1/players/me", { name: "Alice B" }, p.token);
    expect(renamed.body.name).toBe("Alice B");
    expect((await call("PATCH", "/v1/players/me", { name: "Bob" }, "wrong")).status).toBe(401);
  });

  it("turns away outdated clients", async () => {
    const res = await SELF.fetch("https://api.test/v1/players", {
      method: "POST",
      headers: { "x-client-version": "0.9.0" },
      body: JSON.stringify({ name: "Old" }),
    });
    expect(res.status).toBe(426);
  });
});

describe("ranked games", () => {
  it("accepts a replayed win, ranks it, and keeps the personal best", async () => {
    const p = await register("Speedy");
    const game = (await call("POST", "/v1/games", { level: "beginner" }, p.token)).body;
    expect(game.seed).toBeTypeOf("number");

    const moves = solve(game.seed, 50);
    await backdate(game.id, 60_000);
    const done = await call("POST", `/v1/games/${game.id}/finish`, { moves }, p.token);
    expect(done.status).toBe(200);
    expect(done.body).toMatchObject({ timeMs: moves.at(-1)!.t, personalBest: true, best: { rank: 1 } });

    // Same game can't be submitted twice.
    expect((await call("POST", `/v1/games/${game.id}/finish`, { moves }, p.token)).status).toBe(409);

    // A slower game is accepted but isn't a new best.
    const slow = (await call("POST", "/v1/games", { level: "beginner" }, p.token)).body;
    await backdate(slow.id, 600_000);
    const slower = await call("POST", `/v1/games/${slow.id}/finish`, { moves: solve(slow.seed, 5_000) }, p.token);
    expect(slower.body.personalBest).toBe(false);

    const board = await call("GET", "/v1/leaderboard/beginner", undefined, p.token);
    expect(board.body.entries).toEqual([expect.objectContaining({ rank: 1, name: "Speedy", timeMs: moves.at(-1)!.t })]);
    expect(board.body.me).toMatchObject({ rank: 1 });
  });

  it("rejects a time faster than the server clock allows", async () => {
    const p = await register("Cheater");
    const game = (await call("POST", "/v1/games", { level: "beginner" }, p.token)).body;
    const res = await call("POST", `/v1/games/${game.id}/finish`, { moves: solve(game.seed, 10_000) }, p.token);
    expect(res.status).toBe(422);
  });

  it("rejects moves that don't win against the issued seed", async () => {
    const p = await register("Guesser");
    const game = (await call("POST", "/v1/games", { level: "beginner" }, p.token)).body;
    const res = await call("POST", `/v1/games/${game.id}/finish`, { moves: solve(game.seed + 1, 1) }, p.token);
    expect(res.status).toBe(422);
  });

  it("does not let players finish each other's games or play custom boards", async () => {
    const a = await register("Player A");
    const b = await register("Player B");
    const game = (await call("POST", "/v1/games", { level: "beginner" }, a.token)).body;
    expect((await call("POST", `/v1/games/${game.id}/finish`, { moves: [] }, b.token)).status).toBe(404);
    expect((await call("POST", "/v1/games", { level: "custom" }, a.token)).status).toBe(400);
  });
});
