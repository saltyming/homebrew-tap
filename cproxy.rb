class Cproxy < Formula
  desc "One CLI to switch between Claude Code providers instantly"
  homepage "https://github.com/saltyming/cproxy"
  url "https://github.com/saltyming/cproxy/archive/refs/tags/v3.1.0.tar.gz"
  sha256 "0ba4c2576cdcb734d25835d891c395ae9563b2d31bec4d5a41e30a2ebe0615f2"
  license "MIT"
  head "https://github.com/saltyming/cproxy.git", branch: "main"

  depends_on "go" => :build

  conflicts_with "clother", because: "cproxy is a personal fork of clother; install only one"

  def install
    ldflags = ["-s", "-w", "-X", "github.com/saltyming/cproxy/internal/version.Value=v#{version}"]
    system "go", "build", *std_go_args(output: bin/"cproxy", ldflags: ldflags), "./cmd/cproxy"
  end

  test do
    output = shell_output("#{bin}/cproxy --help 2>&1")
    assert_match "Cproxy", output
    assert_match "config", output
  end
end
