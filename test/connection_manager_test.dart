import 'dart:async';
import 'dart:convert';

import 'package:dhook/dhook.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Mock WebSocketChannel for testing
class MockWebSocketChannel with StreamChannelMixin implements WebSocketChannel {
  final List<dynamic> sentMessages = [];
  bool isClosed = false;
  final StreamController _streamController = StreamController.broadcast();

  @override
  WebSocketSink get sink => MockWebSocketSink(this);

  @override
  Stream get stream => _streamController.stream;

  @override
  int? get closeCode => isClosed ? 1000 : null;

  @override
  String? get closeReason => isClosed ? 'Normal closure' : null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();
}

class MockWebSocketSink implements WebSocketSink {
  final MockWebSocketChannel channel;

  MockWebSocketSink(this.channel);

  @override
  void add(dynamic data) {
    channel.sentMessages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) => Future.value();

  @override
  Future close([int? closeCode, String? closeReason]) async {
    channel.isClosed = true;
  }

  @override
  Future get done => Future.value();
}

void main() {
  group('ConnectionManager', () {
    late ConnectionManager manager;

    setUp(() {
      manager = ConnectionManager();
    });

    tearDown(() async {
      await manager.closeAll();
    });

    test('subscribe adds socket to channel', () {
      final socket = MockWebSocketChannel();

      manager.subscribe('test-channel', socket);

      expect(manager.subscriberCount('test-channel'), 1);
    });

    test('subscribe creates channel if not exists', () {
      final socket = MockWebSocketChannel();

      expect(manager.subscriberCount('new-channel'), 0);
      manager.subscribe('new-channel', socket);
      expect(manager.subscriberCount('new-channel'), 1);
    });

    test('subscribe multiple sockets to same channel', () {
      final socket1 = MockWebSocketChannel();
      final socket2 = MockWebSocketChannel();
      final socket3 = MockWebSocketChannel();

      manager.subscribe('multi-channel', socket1);
      manager.subscribe('multi-channel', socket2);
      manager.subscribe('multi-channel', socket3);

      expect(manager.subscriberCount('multi-channel'), 3);
    });

    test('unsubscribe removes socket from channel', () async {
      final socket = MockWebSocketChannel();
      manager.subscribe('test-channel', socket);

      await manager.unsubscribe('test-channel', socket);

      expect(manager.subscriberCount('test-channel'), 0);
    });

    test('unsubscribe removes empty channel', () async {
      final socket = MockWebSocketChannel();
      manager.subscribe('temp-channel', socket);

      await manager.unsubscribe('temp-channel', socket);

      expect(manager.subscriberCount('temp-channel'), 0);
    });

    test('unsubscribe closes socket', () async {
      final socket = MockWebSocketChannel();
      manager.subscribe('close-test', socket);

      await manager.unsubscribe('close-test', socket);

      expect(socket.isClosed, isTrue);
    });

    test('broadcast sends message to all subscribers in channel', () {
      final socket1 = MockWebSocketChannel();
      final socket2 = MockWebSocketChannel();
      manager.subscribe('broadcast-channel', socket1);
      manager.subscribe('broadcast-channel', socket2);

      manager.broadcast('broadcast-channel', 'Hello');

      expect(socket1.sentMessages, ['Hello']);
      expect(socket2.sentMessages, ['Hello']);
    });

    test('broadcast does nothing for empty channel', () {
      // Should not throw
      manager.broadcast('nonexistent-channel', 'Message');
    });

    test('broadcast does not affect other channels', () {
      final socket1 = MockWebSocketChannel();
      final socket2 = MockWebSocketChannel();
      manager.subscribe('channel-1', socket1);
      manager.subscribe('channel-2', socket2);

      manager.broadcast('channel-1', 'Only for channel 1');

      expect(socket1.sentMessages, ['Only for channel 1']);
      expect(socket2.sentMessages, isEmpty);
    });

    test('broadcastToAll sends message to all channels', () {
      final socket1 = MockWebSocketChannel();
      final socket2 = MockWebSocketChannel();
      final socket3 = MockWebSocketChannel();
      manager.subscribe('channel-a', socket1);
      manager.subscribe('channel-b', socket2);
      manager.subscribe('channel-b', socket3);

      manager.broadcastToAll('Ping');

      expect(socket1.sentMessages, ['Ping']);
      expect(socket2.sentMessages, ['Ping']);
      expect(socket3.sentMessages, ['Ping']);
    });

    test('subscriberCount returns 0 for unknown channel', () {
      expect(manager.subscriberCount('unknown'), 0);
    });

    test('totalSubscribers counts across all channels', () {
      final s1 = MockWebSocketChannel();
      final s2 = MockWebSocketChannel();
      final s3 = MockWebSocketChannel();
      manager.subscribe('ch1', s1);
      manager.subscribe('ch2', s2);
      manager.subscribe('ch2', s3);

      expect(manager.totalSubscribers, 3);
    });

    test('closeAll closes all sockets and clears channels', () async {
      final socket1 = MockWebSocketChannel();
      final socket2 = MockWebSocketChannel();
      manager.subscribe('channel-1', socket1);
      manager.subscribe('channel-2', socket2);

      await manager.closeAll();

      expect(socket1.isClosed, isTrue);
      expect(socket2.isClosed, isTrue);
      expect(manager.totalSubscribers, 0);
    });
  });

  group('HeartbeatManager', () {
    test('sends ping to all connections on interval', () async {
      final manager = ConnectionManager();
      final socket = MockWebSocketChannel();
      manager.subscribe('heartbeat-test', socket);

      final heartbeat = HeartbeatManager(
        manager,
        const Duration(milliseconds: 100),
      );
      heartbeat.start();

      // Wait for at least one ping
      await Future.delayed(const Duration(milliseconds: 150));
      heartbeat.stop();

      expect(socket.sentMessages.length, greaterThanOrEqualTo(1));

      final pingMessage = jsonDecode(socket.sentMessages.first as String);
      expect(pingMessage['type'], 'ping');
      expect(pingMessage['timestamp'], isNotNull);

      await manager.closeAll();
    });

    test('stop cancels the timer', () async {
      final manager = ConnectionManager();
      final socket = MockWebSocketChannel();
      manager.subscribe('stop-test', socket);

      final heartbeat = HeartbeatManager(
        manager,
        const Duration(milliseconds: 50),
      );
      heartbeat.start();
      heartbeat.stop();

      final countBeforeWait = socket.sentMessages.length;
      await Future.delayed(const Duration(milliseconds: 100));

      // Should not have received more messages after stop
      expect(socket.sentMessages.length, countBeforeWait);

      await manager.closeAll();
    });
  });
}
