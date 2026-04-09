# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

Camo is an SSL image proxy that prevents mixed content warnings on HTTPS pages. It proxies HTTP images through a secure channel using HMAC-SHA1 URL signing. Originally developed by GitHub for use in comments and READMEs.

## Commands

```bash
# Build: compile CoffeeScript → JavaScript
npm run build

# Install test Ruby dependencies
rake bundle

# Run full suite (build + bundle + test)
rake

# Run tests only (requires server already running and bundled)
BUNDLE_GEMFILE=test.gemfile bundle exec ruby test/proxy_test.rb

# Run a single test by name
BUNDLE_GEMFILE=test.gemfile bundle exec ruby test/proxy_test.rb --name test_always_sets_security_headers

# Start the server
CAMO_KEY=0x24FEEDFACEDEADBEEFCAFE npm start

# Docker smoke test (local)
docker build -t camo:smoke . && docker run -e CAMO_KEY=test-secret-key -p 8081:8081 camo:smoke
```

## Runtime Versions

- **Node**: 22 LTS (managed via mise/nvm — see `.nvmrc`)
- **Ruby**: 3.4.9 (managed via mise — see `.ruby-version`)

To activate Ruby locally: `mise use ruby` in the repo root.

## Architecture

**Source of truth is `server.coffee`** (CoffeeScript); `server.js` is the compiled output checked into the repo. Always edit `server.coffee` and rebuild.

### Request Flow

```
GET /<digest>/<hex-encoded-url>
GET /<digest>?url=<image-url>
         |
    HMAC-SHA1 validation (CAMO_KEY)
    → mismatch: 404
         |
    process_url()
    → parse URL, follow redirects (max CAMO_MAX_REDIRECTS, default 4)
    → validate Content-Type against mime-types.json whitelist
    → enforce Content-Length limit (CAMO_LENGTH_LIMIT, default 5 MB)
         |
    stream response with security headers injected
```

Special routes: `GET /` → `hwhat`, `GET /favicon.ico` → `ok`, `GET /status` → connection stats JSON.

### Key Environment Variables

| Variable | Default | Description |
|---|---|---|
| `CAMO_KEY` | *(required)* | Shared HMAC secret |
| `PORT` | `8081` | Listen port |
| `CAMO_LENGTH_LIMIT` | `5242880` | Max proxied content size (bytes) |
| `CAMO_MAX_REDIRECTS` | `4` | Max redirect depth |
| `CAMO_SOCKET_TIMEOUT` | `10` | Request timeout (seconds) |
| `CAMO_LOGGING_ENABLED` | `"disabled"` | Set to `"debug"` for verbose logs |
| `CAMO_KEEP_ALIVE` | `"false"` | HTTP keep-alive |

### Node 22 Compatibility Notes

`server.coffee` uses `request.destroy()` (not the deprecated `abort()`). The socket timeout is set via `requestOptions.timeout` rather than `request.setTimeout()` so it fires even before the TCP connection is established. A `responded` flag prevents `four_oh_four` being called twice when `destroy()` triggers a subsequent error event.

### Test Infrastructure

Tests are Ruby (Test::Unit) and run integration tests against a live server. Mock backend servers live in `test/servers/` as Rack apps (`.ru` files). The test suite starts these mock servers and exercises the proxy end-to-end.

Several tests are marked `omit` for dead external URLs (Google Charts, ebaumsworld, httpwatch). The `test_404s_on_connect_timeout` test is active and exercises the server's socket timeout path.

`scripts/gen_url.rb` generates valid HMAC-signed Camo URLs for manual testing.

### URL Signing (for testing)

```bash
# bash (openssl + xxd)
KEY="0x24FEEDFACEDEADBEEFCAFE"
URL="http://example.com/image.jpg"
DIGEST=$(printf '%s' "$URL" | openssl dgst -sha1 -hmac "$KEY" | awk '{print $NF}')
HEX_URL=$(printf '%s' "$URL" | xxd -p | tr -d '\n')
echo "http://localhost:8081/$DIGEST/$HEX_URL"
```

```ruby
require 'openssl'
key    = ENV['CAMO_KEY']
url    = 'http://example.com/image.jpg'
digest = OpenSSL::HMAC.hexdigest('sha1', key, url)
hex_url = url.unpack('H*').first
puts "https://camo-host/#{digest}/#{hex_url}"
```
