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

## 📖 What is DHOOK?

DHOOK is a lightweight webhook relay service that allows you to receive webhooks (from GitHub, Stripe, PayMe, etc.) on your local machine during development.

![structure](images/structure.png)

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

# Configure environment
cp .env.example .env
# Edit .env with your server IP

# Run with Docker
docker-compose up -d
```

### 2. CLI Agent (on your machine)

```bash
# Set environment variables
export DHOOK_SERVER=wss://your-server.com/ws/my-channel
export DHOOK_TARGET=http://localhost:8000

# Run the client
dhook client \
  --server $DHOOK_SERVER \
  --target $DHOOK_TARGET
```

### 3. Configure Your Webhook

Point your webhook to:
```
https://your-server.com/webhook/my-channel
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
# Start relay server on default port 3000
dhook server

# Start on custom port
dhook server --port 8080
```

### Client Commands

```bash
# Connect to relay and forward to localhost
dhook client \
  --server wss://your-server.com/ws/my-channel \
  --target http://localhost:8000
```

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Health check |
| `/new` | GET | Generate new channel (redirects to /channel/<id>) |
| `/ws/<channel>` | WS | WebSocket connection for CLI |
| `/webhook/<channel>` | ANY | Receive webhooks |
| `/webhook/<channel>/<path>` | ANY | Receive webhooks with subpath |

## 📦 Programmatic Usage

```dart
import 'package:dhook/dhook.dart';

// Start a relay server
final server = RelayServer(port: 3000);
await server.start();

// Start a CLI agent
final agent = CliAgent(
  serverUrl: 'wss://your-server.com/ws/my-channel',
  targetUrl: 'http://localhost:8000',
);
await agent.start();
```

## ⚙️ Configuration

Copy `.env.example` to `.env` and configure:

```bash
# Server IP address or domain
DHOOK_SERVER_HOST=your-server-ip

# Server port (default: 3000)
DHOOK_SERVER_PORT=3000
```

## 🏗️ Architecture

```
dhook/
├── bin/
│   └── dhook.dart          # CLI entry point
├── lib/
│   ├── dhook.dart          # Library exports
│   └── src/
│       ├── client/
│       │   └── cli_agent.dart      # WebSocket client
│       ├── server/
│       │   └── relay_server.dart   # HTTP/WebSocket server
│       ├── models/
│       │   └── webhook_payload.dart
│       └── utils/
│           └── logger.dart
├── Dockerfile
└── docker-compose.yml
```

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 👤 Author

**Alisher Axmedov**
- GitHub: [@alisheraxmedov](https://github.com/alisheraxmedov)
- Email: alisheraxmedov4x4@gmail.com

## 🤝 Contributing

We welcome contributions from the community! If you would like to contribute to this project, please read our [Contributing Guidelines](CONTRIBUTE.md) for detailed instructions on how to get started.

---

<div align="center">

Made with ❤️ in Uzbekistan 🇺🇿

</div>