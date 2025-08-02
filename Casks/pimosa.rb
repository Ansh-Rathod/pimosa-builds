cask "pimosa" do
  version "1.3.0,26"
  sha256 "dea4b99afed7695ea78ea4ba4d46d2e604bb0e744ae5f5732e2ac6197d97677a"

  url "https://github.com/Ansh-Rathod/pimosa-builds/releases/download/v#{version.before_comma}+#{version.after_comma}/Pimosa.zip",
      verified: "github.com/Ansh-Rathod/pimosa-builds/"
  name "Pimosa"
  desc "Offline media toolkit for video, audio, and images"
  homepage "https://pimosa.app"

  livecheck do
    url "https://github.com/Ansh-Rathod/pimosa-builds"
    strategy :github_latest
  end

  app "Pimosa.app"

  zap trash: [
    "~/Library/Application Support/Pimosa",
    "~/Library/Preferences/com.pimosa.app.plist",
    "~/Library/Saved Application State/com.pimosa.app.savedState"
  ]
end