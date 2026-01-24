# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **API Key Authentication** for secure channel access
  - `--auth` flag for server to enable authentication
  - `--api-key` flag for client to provide authentication token
  - `POST /api/keys` endpoint to generate new API keys
  - `GET /api/keys` endpoint to list registered channels
  - SHA-256 hashed key storage for security
  - Persistent key storage with `--keys-file` option
- Cryptographically secure channel IDs (32 hex characters)
- Rate limiting middleware (100 requests/minute per IP)
- Body size limit (1MB max for webhook payloads)

### Security
- Channel IDs are now generated using `Random.secure()` to prevent guessing
- API keys use `dhk_` prefix with 256-bit entropy
- Keys are stored as SHA-256 hashes (raw keys never stored)
- Added DoS protection via rate limiting
- Added memory protection via body size limit

---

## [1.0.9] - 2026-01-14

### Fixed
- Improved multiple subscribers test reliability

### Changed
- Simplified deploy workflow and fixed git pull conflicts

---

## [1.0.8] - 2026-01-13

### Fixed
- Complete workflow event logic refactor
- Remove skip ci to enable tag workflow trigger

---

## [1.0.7] - 2026-01-12

### Fixed
- Smart version bump with tag check
- PAT token verification for CI/CD

---

## [1.0.6] - 2026-01-11

### Changed
- Refactored CI pipeline for OIDC and PAT triggers
- Updated test files

---

## [1.0.5] - 2026-01-11

### Added
- Examples for pub.dev documentation
- Versioned releases with latest symlink

---

## [1.0.4] - 2026-01-10

### Added
- Beautiful CLI UI with colorful terminal output
- Multi-platform binary releases (Linux, macOS, Windows)

---

## [1.0.3] - 2026-01-10

### Fixed
- Install curl for Docker healthcheck
- Remove pubspec.lock from Dockerfile

---

## [1.0.2] - 2026-01-10

### Fixed
- SSH configuration for deployment
- Git clone and docker compose via SSH

---

## [1.0.1] - 2026-01-10

### Fixed
- Use stable Dart SDK version

### Added
- Docker support with multi-stage build
- CI/CD pipeline with GitHub Actions

---

## [1.0.0] - 2026-01-09

### Added
- Initial release of DHOOK - Webhook Relay Service
- **Server Component**: HTTP/WebSocket relay server using Shelf
  - Health check endpoint at `/`
  - Channel generation at `/new`
  - WebSocket connections at `/ws/<channel>`
  - Webhook reception at `/webhook/<channel>`
  - CORS support for cross-origin requests
  - Heartbeat mechanism to keep connections alive
- **Client Component**: CLI agent for webhook forwarding
  - Auto-reconnect on disconnect
  - Full header and body preservation for HMAC verification
  - Query parameter forwarding
- **Docker Support**: Multi-stage Dockerfile for minimal images
- Colorful terminal logging with `DLogger`
- Comprehensive test suite
