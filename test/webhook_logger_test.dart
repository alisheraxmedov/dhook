import 'dart:io';

import 'package:dhook/dhook.dart';
import 'package:test/test.dart';

void main() {
  group('WebhookLogger', () {
    late WebhookLogger logger;
    late String testDbPath;

    setUp(() {
      testDbPath = 'test_webhooks_${DateTime.now().millisecondsSinceEpoch}.db';
      logger = WebhookLogger(dbPath: testDbPath);
    });

    tearDown(() {
      logger.close();
      final file = File(testDbPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    test('log stores webhook entry', () {
      final entry = WebhookLog(
        channelId: 'test-channel',
        timestamp: DateTime.now(),
        method: 'POST',
        path: '/webhook',
        headers: {'content-type': 'application/json'},
        body: '{"event": "test"}',
        clientIp: '127.0.0.1',
        subscribers: 2,
      );

      logger.log(entry);

      expect(logger.count(), 1);
    });

    test('getByChannel returns logs for specific channel', () {
      logger.log(_createLog('channel-a'));
      logger.log(_createLog('channel-b'));
      logger.log(_createLog('channel-a'));

      final logs = logger.getByChannel('channel-a');

      expect(logs.length, 2);
      expect(logs.every((l) => l.channelId == 'channel-a'), isTrue);
    });

    test('getRecent returns logs in descending order', () {
      logger.log(_createLog('ch1'));
      logger.log(_createLog('ch2'));
      logger.log(_createLog('ch3'));

      final logs = logger.getRecent(limit: 10);

      expect(logs.length, 3);
      expect(logs.first.channelId, 'ch3');
      expect(logs.last.channelId, 'ch1');
    });

    test('getRecent respects limit', () {
      for (var i = 0; i < 10; i++) {
        logger.log(_createLog('ch$i'));
      }

      final logs = logger.getRecent(limit: 5);

      expect(logs.length, 5);
    });

    test('count returns correct number', () {
      expect(logger.count(), 0);

      logger.log(_createLog('a'));
      expect(logger.count(), 1);

      logger.log(_createLog('b'));
      logger.log(_createLog('c'));
      expect(logger.count(), 3);
    });

    test('deleteOlderThan removes old entries', () {
      final oldEntry = WebhookLog(
        channelId: 'old',
        timestamp: DateTime.now().subtract(const Duration(days: 10)),
        method: 'POST',
        path: '/',
        headers: {},
        body: '',
        clientIp: '0.0.0.0',
        subscribers: 0,
      );
      logger.log(oldEntry);
      logger.log(_createLog('new'));

      logger.deleteOlderThan(const Duration(days: 5));

      expect(logger.count(), 1);
      expect(logger.getRecent().first.channelId, 'new');
    });

    test('WebhookLog toJson returns correct format', () {
      final log = WebhookLog(
        id: 1,
        channelId: 'test',
        timestamp: DateTime.parse('2026-01-01T12:00:00'),
        method: 'POST',
        path: '/hook',
        headers: {'x-key': 'value'},
        body: 'body',
        clientIp: '1.2.3.4',
        subscribers: 3,
      );

      final json = log.toJson();

      expect(json['id'], 1);
      expect(json['channel_id'], 'test');
      expect(json['method'], 'POST');
      expect(json['subscribers'], 3);
    });
  });
}

WebhookLog _createLog(String channelId) {
  return WebhookLog(
    channelId: channelId,
    timestamp: DateTime.now(),
    method: 'POST',
    path: '/',
    headers: {},
    body: '',
    clientIp: '127.0.0.1',
    subscribers: 1,
  );
}
