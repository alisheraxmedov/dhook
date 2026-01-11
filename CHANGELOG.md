## 1.0.4

- Automated release on 2026-01-11

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0

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
- **CI/CD Pipeline**: Automated testing, building, and deployment
- Colorful terminal logging with `DLogger`
- Comprehensive test suite
