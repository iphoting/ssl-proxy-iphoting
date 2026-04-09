# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

Camo is an SSL image proxy that prevents mixed content warnings on HTTPS pages. It proxies HTTP images through a secure channel using HMAC-SHA1 URL signing. Originally developed by GitHub for use in comments and READMEs.

## Commands

```bash
# Build: compile CoffeeScript → JavaScript
npm run build
# or via rake:
rake build

# Install test Ruby dependencies
rake bundle

# Run full suite (build + bundle + test)
rake

# Run tests only (requires server already running and bundled)
BUNDLE_GEMFILE=test.gemfile bundle exec ruby test/proxy_test.rb

# Start the server
CAMO_KEY=0x24FEEDFACEDEADBEEFCAFE npm start
```

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

### Test Infrastructure

Tests are Ruby (Test::Unit) and run integration tests against a live server. Mock backend servers live in `test/servers/` as Rack apps (`.ru` files). The test suite starts these mock servers and exercises the proxy end-to-end.

`scripts/gen_url.rb` generates valid HMAC-signed Camo URLs for manual testing.

### URL Signing (for testing)

```ruby
require 'openssl'
key   = ENV['CAMO_KEY']
url   = 'http://example.com/image.jpg'
digest = OpenSSL::HMAC.hexdigest('sha1', key, url)
hex_url = url.unpack('H*').first
puts "https://camo-host/#{digest}/#{hex_url}"
```
