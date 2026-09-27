# Minesweeper for Mac

A pixel-perfect remake of the classic Windows Minesweeper for macOS — same board,
same LED counters, same smiley, same rules — plus an online leaderboard.

## Install

```sh
brew install --cask calpimm/tap/minesweeper
```

Or download the latest `Minesweeper-x.y.z.zip` from [Releases](https://github.com/Calpimm/minesweeper/releases).
Requires macOS 14 Sonoma or later (Apple silicon and Intel).

Update with `brew upgrade --cask minesweeper`; the app also tells you when a new version is out
(**Minesweeper ▸ Check for Updates…**).

## Playing

| Action | How |
|---|---|
| Open a square | Click |
| Flag / question mark | Right-click or Control-click |
| Open around a number ("chord") | Both buttons, middle button, or Option-click |
| New game | Click the face, F2 or ⌘N |

**Game** menu: Beginner (9×9, 10 mines), Intermediate (16×16, 40), Expert (30×16, 99),
Custom… (up to 30×24, 667 mines), Marks (?), Color, Sound, Best Times…
**View** menu zooms the pixel art (⌘0 / ⌘+ / ⌘−).

The rules follow Windows 3.1–XP exactly: the first click never hits a mine (it moves to the
top-left free square), the clock starts at 1 and stops at 999, flags stop the flood fill,
question marks don't.

### Online leaderboard

After your first win the game offers to put you on the leaderboard; just pick a name
(**Game ▸ Join Online Leaderboard…** works any time). From then on every Beginner,
Intermediate and Expert game is ranked, and **Game ▸ Online Leaderboard…** (⌘L) shows the
fastest players to the millisecond.

Only your nickname and ranked games are sent. The secret that proves the name is yours is
kept in your login keychain. Custom games, and games started while offline, aren't ranked.

**Fair play:** the server chooses each ranked minefield and replays your moves before
accepting a time, so faked or edited times are rejected.

## Development

```sh
swift run                 # play
scripts/test.sh           # Swift tests (works with Xcode or just the Command Line Tools)
scripts/build-app.sh      # build/Minesweeper.app + zip
```

The leaderboard server is a Cloudflare Worker with a D1 database in [`server/`](server):

```sh
cd server
npm install
npm test                  # runs inside the Workers runtime against a local D1
npm run migrate:local && npm run dev
MINESWEEPER_API_URL=http://localhost:8787 swift run   # from the repo root
```

### Layout

```
Sources/Minesweeper/   the Mac app (AppKit; pixel art rendered in code)
  Game.swift           rules, seeded minefields, move log
  Renderer.swift       draws the window pixel by pixel
  Online.swift         leaderboard client + keychain
server/                Cloudflare Worker: players, ranked games, leaderboard
  src/game.ts          the same rules, used to replay submitted games
shared/test-vectors.json   minefields both implementations must agree on
scripts/               build, test, version and Homebrew cask helpers
```

`Game.swift` and `server/src/game.ts` must stay in lockstep; both test suites check
`shared/test-vectors.json`.

## Releasing

See [docs/RELEASING.md](docs/RELEASING.md). In short: bump `AppInfo.version`, add a
`CHANGELOG.md` section, merge, and push a `vX.Y.Z` tag. GitHub Actions builds a universal app,
signs and notarizes it, publishes the release, and updates the Homebrew tap.

## License

[MIT](LICENSE). Minesweeper is a classic game; this is an independent fan remake, not affiliated
with Microsoft.
