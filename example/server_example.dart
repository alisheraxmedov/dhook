// Copyright (c) 2025 Alisher Axmedov
// Licensed under the MIT License.

/// Server Example - Running DHOOK Relay Server
///
/// This example shows how to start and manage the relay server programmatically.
library;

import 'dart:io';
import 'package:dhook/dhook.dart';

void main() async {
  // Configure the server port (default: 3000)
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 3000;

  // Create the relay server
  final server = RelayServer(port: port);

  // Handle graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down...');
    await server.stop();
    exit(0);
  });

  // Start the server
  await server.start();

  // Server endpoints:
  // GET  /           - Health check
  // GET  /new        - Generate new channel ID
  // WS   /ws/<id>    - WebSocket connection for clients
  // ANY  /webhook/<id> - Receive webhooks
}
