import 'dart:convert';

/// Represents a webhook request payload.
///
/// DHOOK acts as a "postman" (relay) and stores the body as a raw String
/// to preserve HMAC signature verification integrity.
class WebhookPayload {
  /// HTTP method (GET, POST, PUT, DELETE, etc.)
  final String method;

  /// HTTP path (e.g., /webhook/github)
  final String path;

  /// HTTP headers (e.g., x-github-event, content-type)
  final Map<String, String> headers;

  /// HTTP body - stored as raw String
  final String body;

  /// URL query parameters (e.g., ?foo=bar)
  final Map<String, String> queryParameters;

  /// Timestamp when the webhook was received
  final DateTime timestamp;

  const WebhookPayload({
    required this.method,
    required this.path,
    required this.headers,
    required this.body,
    required this.queryParameters,
    required this.timestamp,
  });

  /// Creates a [WebhookPayload] from a JSON map.
  factory WebhookPayload.fromJson(Map<String, dynamic> json) {
    final rawBody = json['body'];
    String bodyString;
    if (rawBody is Map || rawBody is List) {
      bodyString = jsonEncode(rawBody);
    } else {
      bodyString = rawBody?.toString() ?? "";
    }

    return WebhookPayload(
      method: json['method']?.toString().toUpperCase() ?? "POST",
      path: json['path']?.toString() ?? "/",
      headers:
          (json['headers'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
      body: bodyString,
      queryParameters:
          (json['queryParameters'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  /// Creates a copy of this payload with the given fields replaced.
  WebhookPayload copyWith({
    String? method,
    String? path,
    Map<String, String>? headers,
    String? body,
    Map<String, String>? queryParameters,
    DateTime? timestamp,
  }) {
    return WebhookPayload(
      method: method ?? this.method,
      path: path ?? this.path,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      queryParameters: queryParameters ?? this.queryParameters,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'WebhookPayload($method $path, ${headers.length} headers, ${body.length} bytes)';
  }

  /// Converts this payload to a JSON map for serialization.
  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'path': path,
      'headers': headers,
      'body': body,
      'queryParameters': queryParameters,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
