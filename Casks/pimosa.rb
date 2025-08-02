cask "pimosa" do
  version "v1.3.0+26"
  sha256 "dea4b99afed7695ea78ea4ba4d46d2e604bb0e744ae5f5732e2ac6197d97677a"

  url "https://github.com/Ansh-Rathod/pimosa-builds/releases/download/v1.3.0%2B26/Pimosa.zip"
  name "Pimosa"
  desc "Offline media toolkit for video, audio, and images"
  homepage "https://pimosa.app"

  app "Pimosa.app"

  zap trash: [
    "~/Library/Application Support/Pimosa",
    "~/Library/Preferences/com.pimosa.app.plist",
    "~/Library/Saved Application State/com.pimosa.app.savedState"
  ]
end