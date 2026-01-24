<div align="center">

<img src="icon_dhook.png" alt="dhook" width="120" />

# DHOOK

**Webhook Relay Service & CLI Tool**

[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![pub.dev](https://img.shields.io/pub/v/dhook?style=for-the-badge)](https://pub.dev/packages/dhook)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)

*Forward webhooks from the cloud to your local development environment in real-time*

</div>

---

## What is DHOOK?

DHOOK is a lightweight, self-hosted webhook relay service designed for developers. When building applications that integrate with external services like GitHub, Stripe, PayMe, or Telegram, you often need to receive webhooks during development. The problem is that these services require a publicly accessible URL, but your local development machine typically sits behind a NAT or firewall.

DHOOK solves this by acting as a relay between the internet and your local machine. You deploy the DHOOK server on any VPS or cloud server with a public IP, then run the DHOOK client on your local machine. The client connects to the server via WebSocket and receives all incoming webhooks in real-time, forwarding them to your local application. This allows you to develop and test webhook integrations without exposing your machine to the internet or paying for tunneling services.

![structure](https://raw.githubusercontent.com/alisheraxmedov/dhook/main/images/structure.png)

## 🚀 Quick Start

### Installation

```bash
# Install globally via pub.dev
dart pub global activate dhook

# Or install from source
dart pub global activate --source git https://github.com/alisheraxmedov/dhook.git
```

### 1. Deploy on Your Server

```bash
# SSH to your server
ssh user@your-server.com

# Clone repository
git clone https://github.com/alisheraxmedov/dhook.git
cd dhook

# Run with Docker
docker-compose up -d
```

### 2. Create API Key

```bash
curl -X POST https://your-server.com/api/keys \
  -H "Content-Type: application/json" \
  -d '{"channel": "my-channel", "name": "production"}'

# Response: {"api_key": "dhk_xxx...", ...}
```

### 3. CLI Agent (on your machine)

```bash
dhook client \
  --server wss://your-server.com/ws/my-channel \
  --target http://localhost:8000 \
  --api-key dhk_xxx...
```

### 4. Configure Your Webhook

Point your webhook to:
```
https://your-server.com/webhook/my-channel
```

## 🔐 Authentication

DHOOK uses API key authentication by default to secure your channels.

### Create API Key

```bash
# First, start the server
dhook server --port 3000

# Create API key for your channel
curl -X POST https://your-server.com/api/keys \
  -H "Content-Type: application/json" \
  -d '{"channel": "my-channel", "name": "production"}'

# Response:
# {"api_key": "dhk_xxx...", "channel": "my-channel", ...}
```

### Connect with API Key

```bash
dhook client \
  --server wss://your-server.com/ws/my-channel \
  --target http://localhost:8000 \
  --api-key dhk_xxx...
```

### Disable Auth (Local Development Only)

```bash
# ⚠️ NOT recommended for production!
dhook server --port 3000 --no-auth
```

## 🐳 Docker Deployment

```bash
# Build and run
docker-compose up -d

# Check logs
docker-compose logs -f

# Stop
docker-compose down
```

## 🛠️ Usage

### Server Commands

```bash
# Start relay server (auth enabled by default)
dhook server

# Start on custom port
dhook server --port 8080

# Disable auth (local development only)
dhook server --port 3000 --no-auth
```

### Client Commands

```bash
dhook client \
  --server wss://your-server.com/ws/my-channel \
  --target http://localhost:8000 \
  --api-key dhk_your_api_key
```

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Health check |
| `/new` | GET | Generate new channel (redirects to /channel/<id>) |
| `/ws/<channel>` | WS | WebSocket connection for CLI |
| `/webhook/<channel>` | ANY | Receive webhooks |
| `/webhook/<channel>/<path>` | ANY | Receive webhooks with subpath |
| `/api/keys` | POST | Create new API key (auth mode) |
| `/api/keys` | GET | List registered channels (auth mode) |

## 📦 Programmatic Usage

```dart
import 'package:dhook/dhook.dart';

// Start relay server (auth enabled by default)
final server = RelayServer(
  port: 3000,
  apiKeyStoragePath: 'keys.json',
);
await server.start();

// Start a CLI agent with API key
final agent = CliAgent(
  serverUrl: 'wss://your-server.com/ws/my-channel',
  targetUrl: 'http://localhost:8000',
  apiKey: 'dhk_xxx...',
);
await agent.start();
```

## 🏗️ Architecture

```
dhook/
├── bin/
│   └── dhook.dart              # CLI entry point
├── lib/
│   ├── dhook.dart              # Library exports
│   └── src/
│       ├── client/
│       │   └── cli_agent.dart        # WebSocket client
│       ├── server/
│       │   ├── relay_server.dart     # HTTP/WebSocket server
│       │   ├── api_key_manager.dart  # API key authentication
│       │   └── rate_limiter.dart     # DoS protection
│       ├── models/
│       │   └── webhook_payload.dart
│       └── utils/
│           └── logger.dart
├── Dockerfile
└── docker-compose.yml
```

## 🔒 Security Features

- **API Key Authentication**: Secure channels with `dhk_` prefixed tokens
- **Rate Limiting**: 100 requests/minute per IP (DoS protection)
- **Body Size Limit**: 1MB max for webhook payloads
- **Cryptographic IDs**: Secure channel ID generation
- **TLS/SSL Support**: Use with Nginx reverse proxy

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 👤 Author

**Alisher Axmedov**
- GitHub: [@alisheraxmedov](https://github.com/alisheraxmedov)
- Email: alisheraxmedov4x4@gmail.com

## 🤝 Contributing

We welcome contributions from the community! If you would like to contribute to this project, please read our [Contributing Guidelines](CONTRIBUTING.md) for detailed instructions on how to get started.

## ☕ Support

If you find DHOOK useful, consider buying me a coffee!

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/alisheraxmedov)

---

<div align="center">

Made with ❤️ in Uzbekistan 🇺🇿

</div>