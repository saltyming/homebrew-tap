class Tailscale < Formula
  desc "Easiest, most secure way to use WireGuard and 2FA"
  homepage "https://tailscale.com"
  url "https://github.com/tailscale/tailscale.git",
      tag:      "v1.104.5",
      revision: "73a48057aaf5f60e4f770b398e9b7af576b01dbe"
  license "BSD-3-Clause"
  revision 1

  # Short MagicDNS names with global DNS in the open-source macOS tailscaled
  # (tailscale/tailscale#21794); the fix of pull request #21795, commit 2687e058.
  patch :DATA

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
    strategy :github_latest
  end

  depends_on "go" => :build

  # `test do` block runs tailscaled, which attempts network connections
  allow_network_access! :test

  def fetch
    system "go", "mod", "download"
  end

  def install
    vars = Utils.safe_popen_read("./build_dist.sh", "shellvars")
    ldflags = %W[
      -X tailscale.com/version.longStamp=#{vars.match(/VERSION_LONG="(.*)"/)[1]}
      -X tailscale.com/version.shortStamp=#{vars.match(/VERSION_SHORT="(.*)"/)[1]}
      -X tailscale.com/version.gitCommitStamp=#{vars.match(/VERSION_GIT_HASH="(.*)"/)[1]}
    ]
    system "go", "build", *std_go_args(ldflags:), "./cmd/tailscale"
    system "go", "build", *std_go_args(ldflags:, output: bin/"tailscaled"), "./cmd/tailscaled"

    generate_completions_from_executable(bin/"tailscale", shell_parameter_format: :cobra)
  end

  def caveats
    on_linux do
      <<~EOS
        tailscaled needs root privileges to configure iptables/nftables and DNS.
        Start the root service with:
          sudo --preserve-env=HOME brew services start tailscale

        To run without root, use userspace-networking mode:
          tailscaled --tun=userspace-networking
      EOS
    end
  end

  service do
    run opt_bin/"tailscaled"
    # See the caveats for userspace/non-root mode
    require_root true
    keep_alive true
    log_path var/"log/tailscaled.log"
    error_log_path var/"log/tailscaled.log"
  end

  test do
    version_text = shell_output("#{bin}/tailscale version")
    assert_match version.to_s, version_text
    assert_match(/commit: [a-f0-9]{40}/, version_text)

    spawn bin/"tailscaled", "-tun=userspace-networking", "-socket=#{testpath}/tailscaled.socket"
    sleep 2
    assert_match "Logged out.", shell_output("#{bin}/tailscale --socket=#{testpath}/tailscaled.socket status", 1)
  end
end

__END__
From 2687e058f2733cfaded24c5a3af6bea9dfaa791d Mon Sep 17 00:00:00 2001
From: Dima Semyushkin <git@devg.ru>
Date: Wed, 14 Oct 2026 23:06:05 +0300
Subject: [PATCH] net/dns: preserve search domains in macOS tailscaled global
 DNS

configd strips SearchDomains from supplemental resolvers and builds
its global search list from their non-empty match domains. The global
macOS daemon configuration registers only an empty catch-all match
domain, so short MagicDNS names fail unless the tailnet suffix also
comes from the local network or manual configuration.

Include the configured search suffixes in SupplementalMatchDomains,
keeping the empty catch-all and the supplied suffix order. Cover empty,
single-label, and ordered search lists in the configurator tests.

RELNOTE: Fix short MagicDNS name resolution with global DNS in the
open-source macOS tailscaled daemon.

Fixes #21794
Updates #20280

Change-Id: Ie098954bc9dd3445e196761a8f29d39aa909610d
Co-authored-by: Codex <noreply@openai.com>
Signed-off-by: Dima Semyushkin <git@devg.ru>
---
 net/dns/manager_darwin.go      | 11 +++++++-
 net/dns/manager_darwin_test.go | 46 +++++++++++++++++++++++++++++++++-
 2 files changed, 55 insertions(+), 2 deletions(-)

diff --git a/net/dns/manager_darwin.go b/net/dns/manager_darwin.go
index a93a131f646bb..bd0c3a493cd17 100644
--- a/net/dns/manager_darwin.go
+++ b/net/dns/manager_darwin.go
@@ -143,7 +143,16 @@ func (c *darwinConfigurator) setGlobalDNS(cfg OSConfig) error {
 	}
 	script.WriteByte('\n')
 	// An empty SupplementalMatchDomains entry makes this a default resolver.
-	script.WriteString("d.add SupplementalMatchDomains * \"\"\n")
+	// configd strips SearchDomains from supplemental resolvers and builds the
+	// global search list from their non-empty match domains instead. Include
+	// the search suffixes here as well, in control's order, so that single-label
+	// names work without manually configuring search domains on an interface.
+	script.WriteString("d.add SupplementalMatchDomains * \"\"")
+	for _, fqdn := range cfg.SearchDomains {
+		script.WriteByte(' ')
+		writeScutilString(&script, fqdn.WithoutTrailingDot())
+	}
+	script.WriteByte('\n')
 	if len(cfg.SearchDomains) > 0 {
 		script.WriteString("d.add SearchDomains *")
 		for _, fqdn := range cfg.SearchDomains {
diff --git a/net/dns/manager_darwin_test.go b/net/dns/manager_darwin_test.go
index 98af980022be6..b9f5e1c704ac2 100644
--- a/net/dns/manager_darwin_test.go
+++ b/net/dns/manager_darwin_test.go
@@ -151,7 +151,7 @@ func TestSetDNSGlobal(t *testing.T) {
 		"d.init",
 		"d.add SearchOrder # 100000",
 		"d.add ServerAddresses * 100.100.100.100 fd7a:115c:a1e0::53",
-		`d.add SupplementalMatchDomains * ""`,
+		`d.add SupplementalMatchDomains * "" tail1234.ts.net`,
 		"d.add SearchDomains * tail1234.ts.net",
 		"set " + macOSGlobalDNSKey,
 		"quit",
@@ -174,6 +174,50 @@ func TestSetDNSGlobal(t *testing.T) {
 	}
 }
 
+func TestSetDNSGlobalSearchDomains(t *testing.T) {
+	for _, tt := range []struct {
+		name    string
+		domains []dnsname.FQDN
+		want    string
+	}{
+		{
+			name: "none",
+			want: `d.add SupplementalMatchDomains * ""`,
+		},
+		{
+			name:    "single-label",
+			domains: []dnsname.FQDN{"mesh."},
+			want:    `d.add SupplementalMatchDomains * "" mesh`,
+		},
+		{
+			name:    "ordered",
+			domains: []dnsname.FQDN{"tail1234.ts.net.", "office.example."},
+			want:    `d.add SupplementalMatchDomains * "" tail1234.ts.net office.example`,
+		},
+	} {
+		t.Run(tt.name, func(t *testing.T) {
+			c := newTestConfigurator(t)
+			var script string
+			c.runScutil = func(s string) (string, error) {
+				script = s
+				return "", nil
+			}
+			if err := c.SetDNS(OSConfig{
+				Nameservers:   []netip.Addr{netip.MustParseAddr("100.100.100.100")},
+				SearchDomains: tt.domains,
+			}); err != nil {
+				t.Fatal(err)
+			}
+			// configd strips SearchDomains from supplemental resolvers. The
+			// search suffixes must also be match domains, while the empty
+			// match domain must remain to handle global DNS queries.
+			if !slices.Contains(strings.Split(script, "\n"), tt.want) {
+				t.Errorf("scutil script missing %q:\n%s", tt.want, script)
+			}
+		})
+	}
+}
+
 func TestSetDNSSplitRemovesGlobal(t *testing.T) {
 	c := newTestConfigurator(t)
 
