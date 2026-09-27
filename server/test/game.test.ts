import { describe, expect, it } from "vitest";
import vectors from "../../shared/test-vectors.json";
import { LEVELS, mineLayout, replay, type Move } from "../src/game";
import { compareVersions } from "../src/semver";

const beginner = LEVELS.beginner;

/** Wins by opening every safe square in index order, starting from `first`. */
function winningMoves(seed: number, first: number, step = 100): Move[] {
  const mines = new Set(mineLayout(beginner, seed));
  if (mines.has(first)) {
    // Mirror the first-click relocation.
    mines.delete(first);
    for (let i = 0; ; i++) if (!mines.has(i) && i !== first) { mines.add(i); break; }
  }
  const moves: Move[] = [{ t: 0, a: "r", i: first }];
  for (let i = 0; i < 81; i++) if (!mines.has(i) && i !== first) moves.push({ t: moves.length * step, a: "r", i });
  return moves;
}

/** Drops reveals of squares an earlier flood already opened (the client never sends those). */
function compact(seed: number, moves: Move[]): Move[] {
  const kept: Move[] = [];
  for (const move of moves) {
    const attempt = replay(beginner, seed, [...kept, move]);
    if (attempt.ok || attempt.reason === "game was not won") kept.push(move);
  }
  return kept;
}

describe("mine layout", () => {
  it("matches the shared vectors (same as the Swift client)", () => {
    for (const v of vectors.layouts) {
      const size = LEVELS[v.level as keyof typeof LEVELS];
      expect(mineLayout(size, v.seed).sort((a, b) => a - b)).toEqual(v.mines);
    }
  });

  it("places exactly the requested number of mines", () => {
    expect(new Set(mineLayout(LEVELS.expert, 7)).size).toBe(99);
  });
});

describe("replay", () => {
  it("accepts a won game and reports the last move's time", () => {
    const moves = compact(42, winningMoves(42, 0));
    const result = replay(beginner, 42, moves);
    expect(result).toEqual({ ok: true, timeMs: moves.at(-1)!.t });
  });

  it("applies the first-click relocation", () => {
    const mine = mineLayout(beginner, 42)[0];
    const result = replay(beginner, 42, compact(42, winningMoves(42, mine)));
    expect(result.ok).toBe(true);
  });

  it("rejects a game that hits a mine", () => {
    const mines = mineLayout(beginner, 42);
    const safe = [...Array(81).keys()].find((i) => !mines.includes(i))!;
    const moves: Move[] = [{ t: 0, a: "r", i: safe }, { t: 10, a: "r", i: mines.find((m) => m !== safe)! }];
    expect(replay(beginner, 42, moves)).toEqual({ ok: false, reason: "game was not won" });
  });

  it("rejects unfinished games, time travel and junk", () => {
    const moves = compact(42, winningMoves(42, 0));
    expect(replay(beginner, 42, moves.slice(0, -1)).ok).toBe(false);
    expect(replay(beginner, 42, [{ ...moves[0], t: 5 }, ...moves.slice(1)])).toMatchObject({ reason: "clock started early" });
    const backwards = moves.map((m, i) => (i === moves.length - 1 ? { ...m, t: 1 } : m));
    expect(replay(beginner, 42, backwards)).toMatchObject({ reason: "malformed move" });
    expect(replay(beginner, 42, "nope")).toMatchObject({ ok: false });
    expect(replay(beginner, 42, [{ t: 0, a: "x", i: 0 }])).toMatchObject({ ok: false });
  });

  it("rejects a flagged square being opened", () => {
    const moves: Move[] = [{ t: 0, a: "m", i: 3, m: 1 }, { t: 0, a: "r", i: 3 }];
    expect(replay(beginner, 42, moves)).toMatchObject({ reason: "invalid reveal" });
  });
});

describe("versions", () => {
  it("compares semver strings", () => {
    expect(compareVersions("1.10.0", "1.9.9")).toBe(1);
    expect(compareVersions("v1.1.0", "1.1.0")).toBe(0);
    expect(compareVersions("1.0.9", "1.1.0")).toBe(-1);
  });
});
