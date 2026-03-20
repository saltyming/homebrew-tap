class CaddyCloudflare < Formula
  desc "Fast, multi-platform web server with automatic HTTPS and Cloudflare DNS plugin"
  homepage "https://caddyserver.com/"
  url "https://github.com/caddyserver/caddy/archive/refs/tags/v2.11.2.tar.gz"
  sha256 "ee12f7b5f97308708de5067deebb3d3322fc24f6d54f906a47a0a4e8db799122"
  license "Apache-2.0"
  head "https://github.com/caddyserver/caddy.git", branch: "master"

  depends_on "go" => :build

  # xcaddy resource — pinned so we don't depend on a separate formula
  resource "xcaddy" do
    url "https://github.com/caddyserver/xcaddy/archive/refs/tags/v0.4.4.tar.gz"
    sha256 "5ba32eec2388638cebbe1df861ea223c35074528af6a0424f07e436f07adce72"
  end

  def install
    # Build xcaddy first
    resource("xcaddy").stage do
      system "go", "build", *std_go_args(output: buildpath/"xcaddy"), "./cmd/xcaddy"
    end

    # Build caddy with cloudflare DNS plugin via xcaddy
    ENV["XCADDY_WHICH_GO"] = Formula["go"].opt_bin/"go"
    system buildpath/"xcaddy", "build", "v#{version}",
           "--with", "github.com/caddy-dns/cloudflare",
           "--output", bin/"caddy"
  end

  service do
    run [opt_bin/"caddy", "run", "--config", etc/"Caddyfile"]
    keep_alive true
    log_path var/"log/caddy/access.log"
    error_log_path var/"log/caddy/error.log"
  end

  def post_install
    (var/"log/caddy").mkpath
    (etc/"Caddyfile").write <<~CADDYFILE unless (etc/"Caddyfile").exist?
      # Global options
      # {
      #   email your@email.com
      # }

      :80 {
        respond "Hello from Caddy with Cloudflare DNS!"
      }
    CADDYFILE
  end

  test do
    assert_match "cloudflare", shell_output("#{bin}/caddy list-modules 2>&1")
    assert_match version.to_s, shell_output("#{bin}/caddy version 2>&1")
  end

  conflicts_with "caddy", because: "caddy-cloudflare replaces caddy with Cloudflare DNS support"
end
