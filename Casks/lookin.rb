cask "lookin" do
  version "1.0.7"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/TastyHeadphones/Lookin/releases/download/v#{version}/Lookin-#{version}.zip",
      verified: "github.com/TastyHeadphones/Lookin/"
  name "Lookin"
  desc "iOS view-debugging companion app"
  homepage "https://lookin.work/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "Lookin.app"

  zap trash: [
    "~/Library/Application Support/Lookin",
    "~/Library/Caches/hughkli.Lookin",
    "~/Library/Preferences/hughkli.Lookin.plist",
    "~/Library/Saved Application State/hughkli.Lookin.savedState",
  ]
end
