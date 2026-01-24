import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/webhook_payload.dart';
import '../utils/logger.dart';

/// DHOOK CLI Agent - connects to relay server and forwards webhooks to localhost.
class CliAgent {
  final String serverUrl;
  final String targetUrl;
  final String? apiKey;
  final Duration retryDelay;

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _shouldReconnect = true;

  CliAgent({
    required this.serverUrl,
    required this.targetUrl,
    this.apiKey,
    this.retryDelay = const Duration(seconds: 5),
  });

  Future<void> start() async {
    _shouldReconnect = true;
    await _connect();
  }

  Future<void> stop() async {
    _shouldReconnect = false;
    await _channel?.sink.close();
    _isConnected = false;
    DLogger.info('Agent stopped');
  }

  Future<void> _connect() async {
    var connectUrl = serverUrl;

    if (apiKey != null && apiKey!.isNotEmpty) {
      final uri = Uri.parse(serverUrl);
      final params = Map<String, String>.from(uri.queryParameters);
      params['api_key'] = apiKey!;
      connectUrl = uri.replace(queryParameters: params).toString();
    }

    DLogger.connection('Connecting', serverUrl);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(connectUrl));
      await _channel!.ready;
      _isConnected = true;
      DLogger.success('Connected to relay server');

      _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnect,
        onError: _onError,
      );
    } catch (e) {
      DLogger.error('Connection failed', e);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;

      switch (type) {
        case 'ready':
          DLogger.success('Ready to receive webhooks');
          DLogger.info('Forwarding to: $targetUrl');
          break;
        case 'ping':
          break;
        case 'webhook':
          _forwardWebhook(message['payload'] as Map<String, dynamic>);
          break;
        default:
          DLogger.warn('Unknown message type: $type');
      }
    } catch (e) {
      DLogger.error('Error parsing message', e);
    }
  }

  Future<void> _forwardWebhook(Map<String, dynamic> payloadJson) async {
    try {
      final payload = WebhookPayload.fromJson(payloadJson);

      // Build URL with query parameters
      final baseUrl = targetUrl.endsWith('/')
          ? targetUrl.substring(0, targetUrl.length - 1)
          : targetUrl;
      final path = payload.path.startsWith('/')
          ? payload.path
          : '/${payload.path}';
      final uri = Uri.parse('$baseUrl$path').replace(
        queryParameters: payload.queryParameters.isNotEmpty
            ? payload.queryParameters
            : null,
      );

      // Clean headers: remove host and content-length (http package calculates these)
      final cleanHeaders = Map<String, String>.from(payload.headers)
        ..remove('host')
        ..remove('Host')
        ..remove('content-length')
        ..remove('Content-Length');

      DLogger.http(
        payload.method,
        '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}',
        direction: 'out',
      );

      // Use http.Request for flexible method handling
      final request = http.Request(payload.method.toUpperCase(), uri);
      request.headers.addAll(cleanHeaders);
      if (payload.body.isNotEmpty && payload.method.toUpperCase() != 'GET') {
        request.body = payload.body;
      }

      final streamedResponse = await http.Client().send(request);
      DLogger.http(
        payload.method,
        uri.path,
        status: streamedResponse.statusCode,
        direction: 'in',
      );
    } catch (e) {
      DLogger.error('Forward failed', e);
      DLogger.warn('Is your local server running at $targetUrl?');
    }
  }

  void _onDisconnect() {
    DLogger.connection('Disconnected', serverUrl);
    _isConnected = false;
    _scheduleReconnect();
  }

  void _onError(dynamic error) {
    DLogger.error('WebSocket error', error);
    _isConnected = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    DLogger.info('Reconnecting in ${retryDelay.inSeconds}s...');
    Future.delayed(retryDelay, () {
      if (_shouldReconnect) _connect();
    });
  }

  bool get isConnected => _isConnected;
}
