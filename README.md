# homebrew-tap

Personal Homebrew tap for custom formulae.

## Formulae

| Formula | Description |
|---------|-------------|
| `caddy-cloudflare` | [Caddy](https://caddyserver.com/) web server built with [Cloudflare DNS](https://github.com/caddy-dns/cloudflare) plugin for DNS-01 ACME challenges |

## Usage

```bash
brew tap saltyming/tap
brew install caddy-cloudflare
```

## Services

```bash
# Start Caddy as a background service
brew services start caddy-cloudflare

# Edit the Caddyfile
$EDITOR /opt/homebrew/etc/Caddyfile

# Reload after config changes
caddy reload --config /opt/homebrew/etc/Caddyfile
```

## Notes

- `caddy-cloudflare` conflicts with the official `caddy` formula. Uninstall `caddy` first if installed.
- The formula builds Caddy from source using `xcaddy`, so it requires Go.
- Caddyfile is located at `/opt/homebrew/etc/Caddyfile`.
