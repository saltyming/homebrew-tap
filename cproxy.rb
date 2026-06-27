class Cproxy < Formula
  desc "One CLI to switch between Claude Code providers instantly"
  homepage "https://github.com/saltyming/cproxy"
  url "https://github.com/saltyming/cproxy/archive/refs/tags/v3.1.2.tar.gz"
  sha256 "81bbd7bcbc1fdb6518a68f064397f2e0eb12ff0ab772b29ae52968459b51724a"
  license "MIT"
  head "https://github.com/saltyming/cproxy.git", branch: "main"

  depends_on "go" => :build

  conflicts_with "clother", because: "cproxy is a personal fork of clother; install only one"

  def install
    ldflags = ["-s", "-w", "-X", "github.com/saltyming/cproxy/internal/version.Value=#{version}"]
    system "go", "build", *std_go_args(output: bin/"cproxy", ldflags: ldflags), "./cmd/cproxy"
  end

  test do
    output = shell_output("#{bin}/cproxy --help 2>&1")
    assert_match "Cproxy", output
    assert_match "config", output
  end
end
