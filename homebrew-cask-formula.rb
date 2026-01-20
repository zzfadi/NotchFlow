# Homebrew Cask Formula for NotchFlow
#
# After your first release, submit this as a PR to:
# https://github.com/Homebrew/homebrew-cask
#
# File should be named: Casks/n/notchflow.rb
#
# Steps:
# 1. Fork homebrew/homebrew-cask
# 2. Create file: Casks/n/notchflow.rb with contents below
# 3. Update sha256 with value from your GitHub release
# 4. Submit PR
#
# See: https://docs.brew.sh/Adding-Software-to-Homebrew#cask-stanza-reference

cask "notchflow" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE"

  url "https://github.com/zzfadi/NotchFlow/releases/download/v#{version}/NotchFlow-#{version}.dmg"
  name "NotchFlow"
  desc "Developer mini-apps in your MacBook notch"
  homepage "https://github.com/zzfadi/NotchFlow"

  depends_on macos: ">= :sonoma"

  app "NotchFlow.app"

  zap trash: [
    "~/Library/Application Support/NotchFlow",
    "~/Library/Preferences/com.notchflow.app.plist",
    "~/Library/Caches/com.notchflow.app",
    "~/Documents/FogNotes",
  ]
end
