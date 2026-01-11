// Copyright (c) 2025 Alisher Axmedov
// Licensed under the MIT License.

/// Client Example - DHOOK CLI Agent
///
/// This example shows how to use the CLI agent to forward webhooks
/// from a relay server to your local development environment.
library;

import 'dart:io';
import 'package:dhook/dhook.dart';

void main() async {
  // Configuration from environment or defaults
  final serverUrl =
      Platform.environment['DHOOK_SERVER'] ??
      'ws://your-server.com:3000/ws/my-channel';

  final targetUrl =
      Platform.environment['DHOOK_TARGET'] ?? 'http://localhost:8000';

  print('DHOOK Client Example');
  print('=' * 50);
  print('Server: $serverUrl');
  print('Target: $targetUrl');
  print('');

  // Create the CLI agent
  final agent = CliAgent(
    serverUrl: serverUrl,
    targetUrl: targetUrl,
    retryDelay: const Duration(seconds: 5),
  );

  // Handle graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nDisconnecting...');
    await agent.stop();
    exit(0);
  });

  // Start the agent
  // It will automatically:
  // - Connect to the relay server
  // - Reconnect on disconnect
  // - Forward all received webhooks to the target URL
  await agent.start();
}
