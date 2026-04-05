class Quickdev < Formula
  desc "QuickDev CLI for scanning and indexing local projects"
  homepage "https://github.com/shotastage/QuickDev"
  url "https://github.com/shotastage/QuickDev/releases/download/v0.0.1/quickdev-0.0.1-darwin-arm64.tar.gz"
  sha256 "REPLACE_WITH_RELEASE_SHA256"
  license "MIT"
  version "0.0.1"

  depends_on :macos

  def install
    bin.install "bin/qd"
    doc.install "README.txt"
    prefix.install "LICENSE"
  end

  test do
    assert_match "QuickDev", shell_output("#{bin}/qd --help")
  end
end
