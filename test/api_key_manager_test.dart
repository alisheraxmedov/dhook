import 'dart:io';

import 'package:dhook/dhook.dart';
import 'package:test/test.dart';

void main() {
  group('ApiKeyManager', () {
    late ApiKeyManager manager;
    late String testFilePath;

    setUp(() {
      testFilePath = 'test_keys_${DateTime.now().millisecondsSinceEpoch}.json';
      manager = ApiKeyManager(storagePath: testFilePath);
    });

    tearDown(() {
      manager.clear();
      final file = File(testFilePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    test('generateKey returns key with dhk_ prefix', () {
      final key = manager.generateKey('test-channel');

      expect(key, startsWith('dhk_'));
      expect(key.length, greaterThan(10));
    });

    test('validateKey returns channel ID for valid key', () {
      final key = manager.generateKey('my-channel');

      final result = manager.validateKey(key);

      expect(result, 'my-channel');
    });

    test('validateKey returns null for invalid key', () {
      final result = manager.validateKey('invalid-key');

      expect(result, isNull);
    });

    test('validateKey returns null for null input', () {
      final result = manager.validateKey(null);

      expect(result, isNull);
    });

    test('validateKeyForChannel returns true for valid key and channel', () {
      final key = manager.generateKey('target-channel');

      final result = manager.validateKeyForChannel(key, 'target-channel');

      expect(result, isTrue);
    });

    test('validateKeyForChannel returns false for wrong channel', () {
      final key = manager.generateKey('channel-a');

      final result = manager.validateKeyForChannel(key, 'channel-b');

      expect(result, isFalse);
    });

    test('validateKeyForChannel returns false for null key', () {
      final result = manager.validateKeyForChannel(null, 'some-channel');

      expect(result, isFalse);
    });

    test('revokeKey removes valid key', () {
      final key = manager.generateKey('revoke-test');
      expect(manager.validateKey(key), 'revoke-test');

      final revoked = manager.revokeKey(key);

      expect(revoked, isTrue);
      expect(manager.validateKey(key), isNull);
    });

    test('revokeKey returns false for unknown key', () {
      final result = manager.revokeKey('unknown-key');

      expect(result, isFalse);
    });

    test('channels returns list of registered channels', () {
      manager.generateKey('ch1');
      manager.generateKey('ch2');
      manager.generateKey('ch3');

      expect(manager.channels, containsAll(['ch1', 'ch2', 'ch3']));
    });

    test('keyCount returns correct count', () {
      expect(manager.keyCount, 0);

      manager.generateKey('a');
      expect(manager.keyCount, 1);

      manager.generateKey('b');
      expect(manager.keyCount, 2);
    });

    test('keys persist across instances', () {
      final key = manager.generateKey('persist-test', name: 'my-key');

      final newManager = ApiKeyManager(storagePath: testFilePath);

      expect(newManager.validateKey(key), 'persist-test');
    });

    test('multiple keys for same channel work independently', () {
      final key1 = manager.generateKey('shared-channel', name: 'key1');
      final key2 = manager.generateKey('shared-channel', name: 'key2');

      expect(key1, isNot(equals(key2)));
      expect(manager.validateKey(key1), 'shared-channel');
      expect(manager.validateKey(key2), 'shared-channel');
      expect(manager.keyCount, 2);
    });

    test('clear removes all keys', () {
      manager.generateKey('a');
      manager.generateKey('b');
      expect(manager.keyCount, 2);

      manager.clear();

      expect(manager.keyCount, 0);
    });
  });
}
