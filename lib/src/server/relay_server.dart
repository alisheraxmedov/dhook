import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/webhook_payload.dart';
import 'api_key_manager.dart';
import 'rate_limiter.dart';

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
    final channelsCopy = Map.of(_channels);
    _channels.clear();

    final List<Future> closeFutures = [];

    for (final channel in channelsCopy.values) {
      for (final socket in channel) {
        closeFutures.add(socket.sink.close().catchError((_) {}));
      }
    }

    await Future.wait(closeFutures);
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
  final bool enableAuth;
  final ConnectionManager _connections = ConnectionManager();
  late final HeartbeatManager _heartbeat;
  HttpServer? _server;

  final RateLimiter _rateLimiter;
  final ApiKeyManager? _apiKeyManager;

  RelayServer({
    this.port = 3000,
    int rateLimit = 100,
    this.enableAuth = false,
    String? apiKeyStoragePath,
  }) : _rateLimiter = RateLimiter(maxRequests: rateLimit),
       _apiKeyManager = apiKeyStoragePath != null || false
           ? ApiKeyManager(storagePath: apiKeyStoragePath)
           : null {
    _heartbeat = HeartbeatManager(_connections);
  }

  Future<void> start() async {
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_rateLimiter.middleware)
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
      final channelId = _generateSecureChannelId();
      return Response.found('/channel/$channelId');
    });

    router.get('/ws/<channelId>', _authenticatedWsHandler);
    router.all('/webhook/<channelId>', _webhookHandler);
    router.all('/webhook/<channelId>/<remaining|.*>', _webhookHandlerWithPath);

    // API Key management endpoints
    router.post('/api/keys', _createApiKey);
    router.get('/api/keys', _listChannels);

    return router;
  }

  Future<Response> _authenticatedWsHandler(
    Request request,
    String channelId,
  ) async {
    if (enableAuth && _apiKeyManager != null) {
      final apiKey =
          request.headers['x-api-key'] ??
          request.requestedUri.queryParameters['api_key'];

      if (!_apiKeyManager.validateKeyForChannel(apiKey, channelId)) {
        return Response.forbidden(
          jsonEncode({'error': 'Invalid or missing API key'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }
    return _wsHandler(channelId)(request);
  }

  Future<Response> _createApiKey(Request request) async {
    if (_apiKeyManager == null) {
      return Response(
        503,
        body: jsonEncode({'error': 'Auth not enabled'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      final bodyStr = await request.readAsString();
      final body = bodyStr.isNotEmpty
          ? jsonDecode(bodyStr) as Map<String, dynamic>
          : <String, dynamic>{};

      final channelId =
          (body['channel'] as String?) ?? _generateSecureChannelId();
      final name = (body['name'] as String?) ?? 'default';

      final key = _apiKeyManager.generateKey(channelId, name: name);

      return Response.ok(
        jsonEncode({
          'api_key': key,
          'channel': channelId,
          'webhook_url': '/webhook/$channelId',
          'websocket_url': '/ws/$channelId',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Invalid request body'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Response _listChannels(Request request) {
    if (_apiKeyManager == null) {
      return Response(
        503,
        body: jsonEncode({'error': 'Auth not enabled'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.ok(
      jsonEncode({
        'channels': _apiKeyManager.channels,
        'total': _apiKeyManager.keyCount,
      }),
      headers: {'Content-Type': 'application/json'},
    );
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

    // Body size limit: 1MB
    if (bodyString.length > 1024 * 1024) {
      return Response(
        413,
        body: jsonEncode({'error': 'Payload too large', 'maxSize': '1MB'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

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

  /// Generates cryptographically secure channel ID [32 hex chars]
  static String _generateSecureChannelId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
