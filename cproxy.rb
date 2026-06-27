class Cproxy < Formula
  desc "One CLI to switch between Claude Code providers instantly"
  homepage "https://github.com/saltyming/cproxy"
  url "https://github.com/saltyming/cproxy/archive/refs/tags/v3.1.1.tar.gz"
  sha256 "5220c1f184d31462afb1cd16e847cbc3c17d3c95edad152e648616ff7c73a9fe"
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
