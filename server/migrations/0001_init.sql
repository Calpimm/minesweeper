-- Players are identified by a nickname and a secret token (only its hash is stored).
CREATE TABLE players (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL UNIQUE COLLATE NOCASE,
  token_hash TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL
);

-- Every ranked game gets a server-issued seed; the finished move list is replayed against it.
CREATE TABLE games (
  id          TEXT PRIMARY KEY,
  player_id   TEXT NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  level       TEXT NOT NULL,
  seed        INTEGER NOT NULL,
  issued_at   INTEGER NOT NULL,
  finished_at INTEGER,
  time_ms     INTEGER,
  status      TEXT NOT NULL DEFAULT 'open' -- open | won | rejected
);
CREATE INDEX games_player_issued ON games(player_id, issued_at);
CREATE INDEX games_status_issued ON games(status, issued_at);

-- One row per player and level: their personal best.
CREATE TABLE best_times (
  player_id   TEXT NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  level       TEXT NOT NULL,
  time_ms     INTEGER NOT NULL,
  game_id     TEXT NOT NULL,
  achieved_at INTEGER NOT NULL,
  PRIMARY KEY (player_id, level)
);
CREATE INDEX best_times_rank ON best_times(level, time_ms, achieved_at);
