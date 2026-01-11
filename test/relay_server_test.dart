import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dhook/dhook.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Generate a random port for testing to avoid conflicts
int getRandomPort() => 10000 + Random().nextInt(50000);

void main() {
  group('RelayServer Integration', () {
    late RelayServer server;
    late int testPort;

    setUp(() async {
      testPort = getRandomPort();
      server = RelayServer(port: testPort);
      await server.start();
    });

    tearDown(() async {
      await server.stop();
      // Give time for port to be released
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('GET / returns health check response', () async {
      final response = await http.get(Uri.parse('http://localhost:$testPort/'));

      expect(response.statusCode, 200);

      final body = jsonDecode(response.body);
      expect(body['status'], 'ok');
      expect(body['service'], 'DHOOK');
    });

    test('GET /new redirects to new channel', () async {
      final client = http.Client();
      final request = http.Request(
        'GET',
        Uri.parse('http://localhost:$testPort/new'),
      );
      request.followRedirects = false;

      final streamedResponse = await client.send(request);

      expect(streamedResponse.statusCode, 302);
      expect(streamedResponse.headers['location'], startsWith('/channel/'));

      client.close();
    });

    test('POST /webhook/<channel> accepts webhook', () async {
      final channelId = 'test-${DateTime.now().millisecondsSinceEpoch}';

      final response = await http.post(
        Uri.parse('http://localhost:$testPort/webhook/$channelId'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'event': 'push', 'ref': 'main'}),
      );

      expect(response.statusCode, 200);

      final body = jsonDecode(response.body);
      expect(body['status'], 'ok');
      expect(body['channel'], channelId);
      expect(body['subscribers'], 0); // No subscribers yet
    });

    test('webhook with path preserves path', () async {
      final channelId = 'path-test';

      final response = await http.post(
        Uri.parse('http://localhost:$testPort/webhook/$channelId/github/push'),
        headers: {'content-type': 'application/json'},
        body: '{}',
      );

      expect(response.statusCode, 200);
    });

    test('webhook accepts all HTTP methods', () async {
      final channelId = 'method-test';
      final methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

      for (final method in methods) {
        final request = http.Request(
          method,
          Uri.parse('http://localhost:$testPort/webhook/$channelId'),
        );
        request.headers['content-type'] = 'application/json';

        final client = http.Client();
        final response = await client.send(request);

        expect(response.statusCode, 200, reason: 'Failed for method: $method');
        client.close();
      }
    });

    test('OPTIONS request returns CORS headers', () async {
      final request = http.Request(
        'OPTIONS',
        Uri.parse('http://localhost:$testPort/webhook/cors-test'),
      );

      final client = http.Client();
      final response = await client.send(request);

      expect(response.statusCode, 200);
      expect(response.headers['access-control-allow-origin'], '*');
      expect(
        response.headers['access-control-allow-methods'],
        contains('POST'),
      );

      client.close();
    });
  });

  group('RelayServer WebSocket', () {
    late RelayServer server;
    late int testPort;

    setUp(() async {
      testPort = getRandomPort();
      server = RelayServer(port: testPort);
      await server.start();
    });

    tearDown(() async {
      await server.stop();
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('WebSocket connection receives ready message', () async {
      final channelId = 'ws-test';
      final socket = await WebSocket.connect(
        'ws://localhost:$testPort/ws/$channelId',
      );

      final completer = Completer<Map<String, dynamic>>();

      socket.listen((data) {
        final message = jsonDecode(data as String);
        if (message['type'] == 'ready') {
          completer.complete(message);
        }
      });

      final readyMessage = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      expect(readyMessage['type'], 'ready');
      expect(readyMessage['channel'], channelId);
      expect(readyMessage['timestamp'], isNotNull);

      await socket.close();
    });

    test('WebSocket receives webhook when posted', () async {
      final channelId = 'webhook-receive-test';

      // Connect WebSocket client
      final socket = await WebSocket.connect(
        'ws://localhost:$testPort/ws/$channelId',
      );

      final webhookCompleter = Completer<Map<String, dynamic>>();

      socket.listen((data) {
        final message = jsonDecode(data as String);
        if (message['type'] == 'webhook') {
          webhookCompleter.complete(message);
        }
      });

      // Wait for ready message to ensure connection is established
      await Future.delayed(const Duration(milliseconds: 100));

      // Send webhook
      await http.post(
        Uri.parse('http://localhost:$testPort/webhook/$channelId'),
        headers: {'content-type': 'application/json', 'x-test': 'value'},
        body: jsonEncode({'test': 'data'}),
      );

      final webhookMessage = await webhookCompleter.future.timeout(
        const Duration(seconds: 5),
      );

      expect(webhookMessage['type'], 'webhook');
      expect(webhookMessage['payload'], isNotNull);

      final payload = webhookMessage['payload'];
      expect(payload['method'], 'POST');
      expect(payload['body'], contains('test'));
      expect(payload['headers']['x-test'], 'value');

      await socket.close();
    });

    test('multiple subscribers receive same webhook', () async {
      final channelId = 'multi-sub-test';

      // Connect two clients
      final socket1 = await WebSocket.connect(
        'ws://localhost:$testPort/ws/$channelId',
      );
      final socket2 = await WebSocket.connect(
        'ws://localhost:$testPort/ws/$channelId',
      );

      final received1 = <String>[];
      final received2 = <String>[];

      socket1.listen((data) {
        final msg = jsonDecode(data as String);
        if (msg['type'] == 'webhook') received1.add(data);
      });
      socket2.listen((data) {
        final msg = jsonDecode(data as String);
        if (msg['type'] == 'webhook') received2.add(data);
      });

      await Future.delayed(const Duration(milliseconds: 100));

      // Send webhook
      await http.post(
        Uri.parse('http://localhost:$testPort/webhook/$channelId'),
        body: 'test',
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(received1.length, 1);
      expect(received2.length, 1);

      await socket1.close();
      await socket2.close();
    });
  });
}
