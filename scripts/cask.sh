#!/bin/bash
# Prints the Homebrew cask for a release: scripts/cask.sh <version> <sha256>
set -euo pipefail
VERSION="$1"
SHA256="$2"
cat <<CASK
cask "minesweeper" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/Calpimm/minesweeper/releases/download/v#{version}/Minesweeper-#{version}.zip"
  name "Minesweeper"
  desc "Pixel-perfect remake of classic Windows Minesweeper with an online leaderboard"
  homepage "https://github.com/Calpimm/minesweeper"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Minesweeper.app"

  zap trash: [
    "~/Library/Preferences/com.calpimm.minesweeper.plist",
    "~/Library/Saved Application State/com.calpimm.minesweeper.savedState",
  ]
end
CASK
