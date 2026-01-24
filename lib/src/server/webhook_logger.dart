import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

/// Webhook log entry model
class WebhookLog {
  final int? id;
  final String channelId;
  final DateTime timestamp;
  final String method;
  final String path;
  final Map<String, String> headers;
  final String body;
  final String clientIp;
  final int subscribers;

  const WebhookLog({
    this.id,
    required this.channelId,
    required this.timestamp,
    required this.method,
    required this.path,
    required this.headers,
    required this.body,
    required this.clientIp,
    required this.subscribers,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'channel_id': channelId,
    'timestamp': timestamp.toIso8601String(),
    'method': method,
    'path': path,
    'headers': headers,
    'body': body,
    'client_ip': clientIp,
    'subscribers': subscribers,
  };

  factory WebhookLog.fromRow(Row row) => WebhookLog(
    id: row['id'] as int,
    channelId: row['channel_id'] as String,
    timestamp: DateTime.parse(row['timestamp'] as String),
    method: row['method'] as String,
    path: row['path'] as String,
    headers: Map<String, String>.from(
      jsonDecode(row['headers'] as String) as Map,
    ),
    body: row['body'] as String,
    clientIp: row['client_ip'] as String,
    subscribers: row['subscribers'] as int,
  );
}

/// SQLite-based webhook logger service
class WebhookLogger {
  final Database _db;

  WebhookLogger._(this._db);

  factory WebhookLogger({String dbPath = 'webhooks.db'}) {
    final db = sqlite3.open(dbPath);
    final logger = WebhookLogger._(db);
    logger._initSchema();
    return logger;
  }

  void _initSchema() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS webhook_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        method TEXT NOT NULL,
        path TEXT NOT NULL,
        headers TEXT NOT NULL,
        body TEXT NOT NULL,
        client_ip TEXT NOT NULL,
        subscribers INTEGER NOT NULL
      )
    ''');

    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_channel_id ON webhook_logs(channel_id)
    ''');

    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_timestamp ON webhook_logs(timestamp)
    ''');
  }

  void log(WebhookLog entry) {
    _db.execute(
      '''
      INSERT INTO webhook_logs 
        (channel_id, timestamp, method, path, headers, body, client_ip, subscribers)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        entry.channelId,
        entry.timestamp.toIso8601String(),
        entry.method,
        entry.path,
        jsonEncode(entry.headers),
        entry.body,
        entry.clientIp,
        entry.subscribers,
      ],
    );
  }

  List<WebhookLog> getByChannel(String channelId, {int limit = 100}) {
    final result = _db.select(
      '''
      SELECT * FROM webhook_logs 
      WHERE channel_id = ? 
      ORDER BY timestamp DESC 
      LIMIT ?
      ''',
      [channelId, limit],
    );
    return result.map(WebhookLog.fromRow).toList();
  }

  List<WebhookLog> getRecent({int limit = 100}) {
    final result = _db.select(
      'SELECT * FROM webhook_logs ORDER BY timestamp DESC LIMIT ?',
      [limit],
    );
    return result.map(WebhookLog.fromRow).toList();
  }

  int count() {
    final result = _db.select('SELECT COUNT(*) as cnt FROM webhook_logs');
    return result.first['cnt'] as int;
  }

  void deleteOlderThan(Duration age) {
    final cutoff = DateTime.now().subtract(age).toIso8601String();
    _db.execute('DELETE FROM webhook_logs WHERE timestamp < ?', [cutoff]);
  }

  void close() {
    _db.dispose();
  }
}
