declare namespace Cloudflare {
  interface Env {
    DB: D1Database;
    MIN_CLIENT_VERSION: string;
    TEST_MIGRATIONS: import("cloudflare:test").D1Migration[];
  }
}
