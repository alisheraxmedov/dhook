import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/webhook_payload.dart';

/// Manages WebSocket connections for all channels.
class ConnectionManager {
  final Map<String, Set<WebSocketChannel>> _channels = {};

  void subscribe(String channelId, WebSocketChannel socket) {
    _channels.putIfAbsent(channelId, () => {});
    _channels[channelId]!.add(socket);
  }

  Future<void> unsubscribe(String channelId, WebSocketChannel socket) async {
    _channels[channelId]?.remove(socket);
    if (_channels[channelId]?.isEmpty ?? false) {
      _channels.remove(channelId);
    }
    // Ensure socket is properly closed to avoid memory leaks
    try {
      await socket.sink.close();
    } catch (_) {}
  }

  void broadcast(String channelId, String message) {
    final subscribers = _channels[channelId];
    if (subscribers == null || subscribers.isEmpty) return;

    for (final subscriber in subscribers) {
      try {
        subscriber.sink.add(message);
      } catch (e) {
        print('Broadcast error: $e');
      }
    }
  }

  void broadcastToAll(String message) {
    for (final channel in _channels.values) {
      for (final socket in channel) {
        try {
          socket.sink.add(message);
        } catch (e) {
          print('Ping error: $e');
        }
      }
    }
  }

  int subscriberCount(String channelId) => _channels[channelId]?.length ?? 0;

  int get totalSubscribers =>
      _channels.values.fold(0, (sum, set) => sum + set.length);

  Future<void> closeAll() async {
    for (final channel in _channels.values) {
      for (final socket in channel) {
        await socket.sink.close();
      }
    }
    _channels.clear();
  }
}

/// Sends periodic pings to keep connections alive.
class HeartbeatManager {
  final ConnectionManager _connections;
  final Duration _interval;
  Timer? _timer;

  HeartbeatManager(
    this._connections, [
    this._interval = const Duration(seconds: 30),
  ]);

  void start() {
    _timer = Timer.periodic(_interval, (_) {
      final ping = jsonEncode({
        'type': 'ping',
        'timestamp': DateTime.now().toIso8601String(),
      });
      _connections.broadcastToAll(ping);
    });
  }

  void stop() => _timer?.cancel();
}

/// DHOOK Relay Server - receives webhooks and forwards to connected clients.
class RelayServer {
  final int port;
  final ConnectionManager _connections = ConnectionManager();
  late final HeartbeatManager _heartbeat;
  HttpServer? _server;

  RelayServer({this.port = 3000}) {
    _heartbeat = HeartbeatManager(_connections);
  }

  Future<void> start() async {
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_cors())
        .addHandler(_router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    _heartbeat.start();
    print('🚀 DHOOK Server running on http://0.0.0.0:$port');
  }

  Future<void> stop() async {
    _heartbeat.stop();
    await _connections.closeAll();
    await _server?.close();
  }

  Router get _router {
    final router = Router();

    router.get(
      '/',
      (Request req) => Response.ok(
        jsonEncode({'status': 'ok', 'service': 'DHOOK'}),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    router.get('/new', (Request req) {
      final channelId = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      return Response.found('/channel/$channelId');
    });

    router.get('/ws/<channelId>', (Request request, String channelId) {
      return _wsHandler(channelId)(request);
    });
    router.all('/webhook/<channelId>', _webhookHandler);
    router.all('/webhook/<channelId>/<remaining|.*>', _webhookHandlerWithPath);

    return router;
  }

  Handler _wsHandler(String channelId) {
    return webSocketHandler((WebSocketChannel socket, String? protocol) {
      _connections.subscribe(channelId, socket);

      socket.sink.add(
        jsonEncode({
          'type': 'ready',
          'channel': channelId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      socket.stream.listen(
        (_) {},
        onDone: () => _connections.unsubscribe(channelId, socket),
        onError: (_) => _connections.unsubscribe(channelId, socket),
      );
    });
  }

  Future<Response> _webhookHandler(Request request, String channelId) async {
    return _handleWebhook(request, channelId, '/');
  }

  Future<Response> _webhookHandlerWithPath(
    Request request,
    String channelId,
    String remaining,
  ) async {
    final originalPath = remaining.isEmpty ? '/' : '/$remaining';
    return _handleWebhook(request, channelId, originalPath);
  }

  Future<Response> _handleWebhook(
    Request request,
    String channelId,
    String originalPath,
  ) async {
    final bodyString = await request.readAsString();

    final payload = WebhookPayload(
      method: request.method,
      path: originalPath,
      headers: Map<String, String>.from(request.headers),
      body: bodyString,
      queryParameters: request.requestedUri.queryParameters,
      timestamp: DateTime.now(),
    );

    final message = {'type': 'webhook', 'payload': payload.toJson()};
    _connections.broadcast(channelId, jsonEncode(message));

    return Response.ok(
      jsonEncode({
        'status': 'ok',
        'channel': channelId,
        'subscribers': _connections.subscriberCount(channelId),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Middleware _cors() =>
      (Handler h) => (Request req) async {
        const headers = {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': '*',
        };
        if (req.method == 'OPTIONS') return Response.ok('', headers: headers);
        return (await h(req)).change(headers: headers);
      };
}
