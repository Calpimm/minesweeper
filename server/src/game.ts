// Server-side copy of the rules in Sources/Minesweeper/Game.swift.
// A submitted game is replayed move by move from its seed; only a replay
// that ends in a win is accepted. Keep both files in lockstep —
// shared/test-vectors.json is checked by both test suites.

export const LEVELS = {
  beginner: { width: 9, height: 9, mines: 10 },
  intermediate: { width: 16, height: 16, mines: 40 },
  expert: { width: 30, height: 16, mines: 99 },
} as const;

export type LevelName = keyof typeof LEVELS;
export type BoardSize = { width: number; height: number; mines: number };

export function isLevel(value: unknown): value is LevelName {
  return typeof value === "string" && Object.hasOwn(LEVELS, value);
}

/** mulberry32, returning an unsigned 32-bit integer. */
export function mulberry32(seed: number): () => number {
  let a = seed | 0;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return (t ^ (t >>> 14)) >>> 0;
  };
}

/** Fisher–Yates shuffle driven by the seed; the first `mines` squares get a mine. */
export function mineLayout(size: BoardSize, seed: number): number[] {
  const rng = mulberry32(seed);
  const squares = Array.from({ length: size.width * size.height }, (_, i) => i);
  for (let i = squares.length - 1; i > 0; i--) {
    const j = rng() % (i + 1);
    [squares[i], squares[j]] = [squares[j], squares[i]];
  }
  return squares.slice(0, size.mines);
}

export type Move = { t: number; a: "r" | "c" | "m"; i: number; m?: number };

export type ReplayResult = { ok: true; timeMs: number } | { ok: false; reason: string };

const FLAG = 1;

export function replay(size: BoardSize, seed: number, moves: unknown): ReplayResult {
  const fail = (reason: string): ReplayResult => ({ ok: false, reason });
  const n = size.width * size.height;
  if (!Array.isArray(moves) || moves.length === 0) return fail("no moves");
  if (moves.length > n * 4) return fail("too many moves");

  const mine = new Uint8Array(n);
  const open = new Uint8Array(n);
  const mark = new Uint8Array(n);
  const adjacent = new Uint8Array(n);
  for (const i of mineLayout(size, seed)) mine[i] = 1;

  const neighbors = (i: number): number[] => {
    const x = i % size.width, y = Math.floor(i / size.width);
    const out: number[] = [];
    for (let dy = -1; dy <= 1; dy++) {
      for (let dx = -1; dx <= 1; dx++) {
        if (dx === 0 && dy === 0) continue;
        const nx = x + dx, ny = y + dy;
        if (nx >= 0 && nx < size.width && ny >= 0 && ny < size.height) out.push(ny * size.width + nx);
      }
    }
    return out;
  };
  const countAdjacent = () => {
    for (let i = 0; i < n; i++) adjacent[i] = neighbors(i).filter((j) => mine[j]).length;
  };
  countAdjacent();

  type Status = "ready" | "playing" | "won" | "lost";
  let status: Status = "ready";
  let openCount = 0;
  let lastT = 0;

  const flood = (start: number) => {
    const stack = [start];
    while (stack.length) {
      const j = stack.pop()!;
      if (open[j] || mark[j] === FLAG) continue;
      open[j] = 1;
      mark[j] = 0;
      openCount++;
      if (adjacent[j] === 0) stack.push(...neighbors(j));
    }
  };
  const outcome = (hit: boolean): Status => (hit ? "lost" : openCount === n - size.mines ? "won" : "playing");

  for (const raw of moves) {
    if (status === "won" || status === "lost") return fail("moves after the game ended");
    if (typeof raw !== "object" || raw === null) return fail("malformed move");
    const { t, a, i, m } = raw as Record<string, unknown>;
    if (!Number.isInteger(t) || !Number.isInteger(i)) return fail("malformed move");
    const time = t as number, sq = i as number;
    if (sq < 0 || sq >= n || time < lastT) return fail("malformed move");
    if (status === "ready" && time !== 0) return fail("clock started early");
    lastT = time;

    switch (a) {
      case "m":
        if (open[sq] || !(m === 0 || m === 1 || m === 2)) return fail("invalid mark");
        mark[sq] = m;
        break;
      case "r":
        if (open[sq] || mark[sq] === FLAG) return fail("invalid reveal");
        if (status === "ready") {
          if (mine[sq]) {
            // First click is always safe: the mine moves to the first free square.
            const free = mine.indexOf(0);
            mine[sq] = 0;
            mine[free] = 1;
            countAdjacent();
          }
          status = "playing";
        }
        if (!mine[sq]) flood(sq);
        status = outcome(mine[sq] === 1);
        break;
      case "c": {
        if (status !== "playing" || !open[sq] || adjacent[sq] === 0) return fail("invalid chord");
        const around = neighbors(sq);
        if (around.filter((j) => mark[j] === FLAG).length !== adjacent[sq]) return fail("invalid chord");
        const targets = around.filter((j) => !open[j] && mark[j] !== FLAG);
        if (targets.length === 0) return fail("invalid chord");
        const hit = targets.some((j) => mine[j]);
        for (const j of targets) if (!mine[j]) flood(j);
        status = outcome(hit);
        break;
      }
      default:
        return fail("malformed move");
    }
  }
  return status === "won" ? { ok: true, timeMs: lastT } : fail("game was not won");
}
