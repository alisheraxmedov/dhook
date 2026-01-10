import 'package:dhook/dhook.dart';
import 'package:test/test.dart';

void main() {
  group('WebhookPayload', () {
    test('fromJson creates valid payload', () {
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
    });

    test('toJson serializes correctly', () {
      final payload = WebhookPayload(
        method: 'GET',
        path: '/',
        headers: {},
        body: '',
        queryParameters: {},
        timestamp: DateTime(2024, 1, 10),
      );

      final json = payload.toJson();

      expect(json['method'], 'GET');
      expect(json['path'], '/');
    });
  });
}
