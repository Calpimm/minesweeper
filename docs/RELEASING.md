# Releasing

## Versioning

- The app version lives in one place: `AppInfo.version` in `Sources/Minesweeper/AppInfo.swift`
  (`scripts/version.sh` prints it). Use [SemVer](https://semver.org/).
- Every version needs a `## [X.Y.Z] - YYYY-MM-DD` section in `CHANGELOG.md`; it becomes the
  release notes.
- If a release changes the rules or the API so that older apps would submit games the server
  can't verify, raise `MIN_CLIENT_VERSION` in `server/wrangler.toml`. Older apps are then told
  to update before playing online (they keep working offline).

## Cutting a release

```sh
# 1. bump AppInfo.version and move "Unreleased" notes into a new CHANGELOG section
# 2. open a PR, let CI pass, merge
git switch main && git pull
git tag v1.2.0 && git push origin v1.2.0
```

The **Release** workflow then:

1. checks that the tag, `AppInfo.version` and `CHANGELOG.md` agree, and runs the tests;
2. builds a universal (arm64 + x86_64) `Minesweeper.app` with the leaderboard URL baked in;
3. signs it with your Developer ID and notarizes + staples it;
4. publishes a GitHub release with the zip and the changelog section;
5. rewrites `Casks/minesweeper.rb` in [Calpimm/homebrew-tap](https://github.com/Calpimm/homebrew-tap).

## One-time setup

### Apple signing and notarization (repository secrets)

| Secret | What |
|---|---|
| `MACOS_CERTIFICATE` | Your **Developer ID Application** certificate + private key exported from Keychain Access as `.p12`, then `base64 -i cert.p12 \| pbcopy` |
| `MACOS_CERTIFICATE_PASSWORD` | The password you gave the `.p12` export |
| `APPLE_ID` | Your Apple Account email |
| `APPLE_TEAM_ID` | 10-character Team ID from developer.apple.com ▸ Membership |
| `APPLE_APP_PASSWORD` | An app-specific password from account.apple.com ▸ Sign-In and Security |

Without `MACOS_CERTIFICATE` releases still publish, ad-hoc signed and with a warning; macOS
will then ask users to approve the app in System Settings ▸ Privacy & Security.

### Homebrew tap (repository secret)

`TAP_GITHUB_TOKEN`: a fine-grained personal access token with **Contents: Read and write** on
`Calpimm/homebrew-tap` only.

### Leaderboard server (Cloudflare)

```sh
cd server
npx wrangler login
npx wrangler d1 create minesweeper      # note the database_id it prints
```

Then in the GitHub repository settings:

| Kind | Name | Value |
|---|---|---|
| Secret | `CLOUDFLARE_API_TOKEN` | API token with the *Edit Cloudflare Workers* template plus **D1: Edit** |
| Secret | `CLOUDFLARE_ACCOUNT_ID` | From the Cloudflare dashboard |
| Variable | `D1_DATABASE_ID` | The id from `wrangler d1 create` |
| Variable | `API_BASE_URL` | The Worker URL, e.g. `https://minesweeper-api.<you>.workers.dev` |

Once `D1_DATABASE_ID` is set, every push to `main` that touches `server/` runs the tests,
applies migrations and deploys (the **Deploy server** workflow; it can also be run by hand).
Put the `API_BASE_URL` in place before tagging, since it's baked into the app at build time.
