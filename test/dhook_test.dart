import 'dart:convert';

import 'package:dhook/dhook.dart';
import 'package:test/test.dart';

void main() {
  group('WebhookPayload', () {
    test('fromJson creates valid payload with all fields', () {
      final json = {
        'method': 'POST',
        'path': '/webhook',
        'headers': {'content-type': 'application/json'},
        'body': '{"test": true}',
        'queryParameters': {'id': '123'},
        'timestamp': '2024-01-10T12:00:00.000Z',
      };

      final payload = WebhookPayload.fromJson(json);

      expect(payload.method, 'POST');
      expect(payload.path, '/webhook');
      expect(payload.body, '{"test": true}');
      expect(payload.headers['content-type'], 'application/json');
      expect(payload.queryParameters['id'], '123');
    });

    test('fromJson handles Map body by serializing to JSON string', () {
      final json = <String, dynamic>{
        'method': 'POST',
        'path': '/',
        'headers': <String, dynamic>{},
        'body': {'nested': 'object'},
        'queryParameters': <String, dynamic>{},
        'timestamp': '2024-01-10T12:00:00.000Z',
      };

      final payload = WebhookPayload.fromJson(json);

      expect(payload.body, '{"nested":"object"}');
    });

    test('fromJson handles List body by serializing to JSON string', () {
      final json = <String, dynamic>{
        'method': 'POST',
        'path': '/',
        'headers': <String, dynamic>{},
        'body': ['item1', 'item2'],
        'queryParameters': <String, dynamic>{},
        'timestamp': '2024-01-10T12:00:00.000Z',
      };

      final payload = WebhookPayload.fromJson(json);

      expect(payload.body, '["item1","item2"]');
    });

    test('fromJson handles null body', () {
      final json = <String, dynamic>{
        'method': 'POST',
        'path': '/',
        'headers': <String, dynamic>{},
        'body': null,
        'queryParameters': <String, dynamic>{},
        'timestamp': '2024-01-10T12:00:00.000Z',
      };

      final payload = WebhookPayload.fromJson(json);

      expect(payload.body, '');
    });

    test('fromJson handles missing fields with defaults', () {
      final payload = WebhookPayload.fromJson(<String, dynamic>{});

      expect(payload.method, 'POST');
      expect(payload.path, '/');
      expect(payload.headers, isEmpty);
      expect(payload.body, '');
      expect(payload.queryParameters, isEmpty);
    });

    test('fromJson normalizes method to uppercase', () {
      final json = <String, dynamic>{'method': 'post'};

      final payload = WebhookPayload.fromJson(json);

      expect(payload.method, 'POST');
    });

    test('toJson serializes correctly', () {
      final timestamp = DateTime(2024, 1, 10, 12, 0, 0);
      final payload = WebhookPayload(
        method: 'GET',
        path: '/api/test',
        headers: {'authorization': 'Bearer token'},
        body: 'test body',
        queryParameters: {'page': '1'},
        timestamp: timestamp,
      );

      final json = payload.toJson();

      expect(json['method'], 'GET');
      expect(json['path'], '/api/test');
      expect(json['headers'], {'authorization': 'Bearer token'});
      expect(json['body'], 'test body');
      expect(json['queryParameters'], {'page': '1'});
      expect(json['timestamp'], timestamp.toIso8601String());
    });

    test('copyWith creates modified copy', () {
      final original = WebhookPayload(
        method: 'GET',
        path: '/',
        headers: {},
        body: '',
        queryParameters: {},
        timestamp: DateTime.now(),
      );

      final modified = original.copyWith(method: 'POST', path: '/new-path');

      expect(modified.method, 'POST');
      expect(modified.path, '/new-path');
      expect(modified.headers, original.headers);
      expect(modified.body, original.body);
    });

    test('copyWith with no arguments returns equivalent payload', () {
      final original = WebhookPayload(
        method: 'DELETE',
        path: '/delete',
        headers: {'x-custom': 'value'},
        body: 'body content',
        queryParameters: {'key': 'val'},
        timestamp: DateTime(2024, 6, 15),
      );

      final copy = original.copyWith();

      expect(copy.method, original.method);
      expect(copy.path, original.path);
      expect(copy.headers, original.headers);
      expect(copy.body, original.body);
      expect(copy.queryParameters, original.queryParameters);
      expect(copy.timestamp, original.timestamp);
    });

    test('toString returns formatted string', () {
      final payload = WebhookPayload(
        method: 'POST',
        path: '/webhook',
        headers: {'a': 'b', 'c': 'd'},
        body: 'Hello World',
        queryParameters: {},
        timestamp: DateTime.now(),
      );

      final str = payload.toString();

      expect(str, contains('POST'));
      expect(str, contains('/webhook'));
      expect(str, contains('2 headers'));
      expect(str, contains('11 bytes'));
    });

    test('roundtrip serialization preserves data', () {
      final original = WebhookPayload(
        method: 'PATCH',
        path: '/api/update',
        headers: {
          'content-type': 'application/json',
          'x-signature': 'sha256=abc123',
        },
        body: jsonEncode({'key': 'value', 'number': 42}),
        queryParameters: {'version': '2'},
        timestamp: DateTime(2024, 3, 15, 10, 30, 0),
      );

      final json = original.toJson();
      final restored = WebhookPayload.fromJson(json);

      expect(restored.method, original.method);
      expect(restored.path, original.path);
      expect(restored.headers, original.headers);
      expect(restored.body, original.body);
      expect(restored.queryParameters, original.queryParameters);
      expect(restored.timestamp, original.timestamp);
    });
  });
}
