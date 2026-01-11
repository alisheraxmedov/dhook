// Copyright (c) 2026 Alisher Axmedov
// Licensed under the MIT License.

/// DHOOK Example - Webhook Relay Service
///
/// This example demonstrates the basic usage of the dhook package.
///
/// ## Running the Server
///
/// Start the relay server on your cloud server:
/// ```bash
/// dart run bin/dhook.dart server --port 3000
/// ```
///
/// ## Running the Client
///
/// Connect to the relay and forward webhooks to your local server:
/// ```bash
/// dart run bin/dhook.dart client \
///   --server ws://your-server.com:3000/ws/my-channel \
///   --target http://localhost:8000
/// ```
///
/// ## Configuring Webhooks
///
/// Point your webhook provider (GitHub, Stripe, PayMe, etc.) to:
/// ```
/// http://your-server.com:3000/webhook/my-channel
/// ```
library;

import 'dart:io';

import 'package:dhook/dhook.dart';

/// Example: Starting a relay server programmatically
Future<void> startServerExample() async {
  // Create a relay server on port 3000
  final server = RelayServer(port: 3000);

  // Start the server
  await server.start();
  print('Server is running on http://localhost:3000');

  // The server will listen for:
  // - WebSocket connections at /ws/<channel-id>
  // - Webhook requests at /webhook/<channel-id>
}

/// Example: Starting a CLI agent programmatically
Future<void> startClientExample() async {
  // Create a CLI agent that connects to the relay server
  // and forwards webhooks to your local development server
  // Use environment variable DHOOK_SERVER or placeholder
  final serverHost =
      Platform.environment['DHOOK_SERVER_HOST'] ?? 'your-server.com';

  final agent = CliAgent(
    serverUrl: 'ws://$serverHost:3000/ws/github-hooks',
    targetUrl: 'http://localhost:8000/api/webhooks',
  );

  // Start the agent
  await agent.start();

  // The agent will:
  // 1. Connect to the relay server via WebSocket
  // 2. Listen for incoming webhooks
  // 3. Forward them to your local server with original headers and body
}

/// Example: Working with webhook payloads
void webhookPayloadExample() {
  // Create a webhook payload
  final payload = WebhookPayload(
    method: 'POST',
    path: '/api/github/push',
    headers: {
      'content-type': 'application/json',
      'x-github-event': 'push',
      'x-hub-signature-256': 'sha256=...',
    },
    body: '{"ref": "refs/heads/main", "commits": [...]}',
    queryParameters: {'token': 'abc123'},
    timestamp: DateTime.now(),
  );

  print('Received ${payload.method} request to ${payload.path}');
  print('Headers: ${payload.headers.length}');
  print('Body size: ${payload.body.length} bytes');

  // Convert to JSON for transmission
  final json = payload.toJson();
  print('Serialized: $json');

  // Recreate from JSON
  final restored = WebhookPayload.fromJson(json);
  print('Restored: ${restored.method} ${restored.path}');
}

void main() async {
  print('DHOOK Example');
  print('=' * 50);

  // Demonstrate webhook payload handling
  print('\n1. Webhook Payload Example:');
  webhookPayloadExample();

  print('\n2. To start a server, run:');
  print('   dart run bin/dhook.dart server --port 3000');

  print('\n3. To start a client, run:');
  print('   dart run bin/dhook.dart client \\');
  print('     --server ws://your-server.com:3000/ws/my-channel \\');
  print('     --target http://localhost:8000');
}
