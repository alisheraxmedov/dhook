import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// API key information stored in manager
class ApiKeyInfo {
  final String channelId;
  final String name;
  final DateTime createdAt;

  const ApiKeyInfo({
    required this.channelId,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ApiKeyInfo.fromJson(Map<String, dynamic> json) => ApiKeyInfo(
    channelId: json['channelId'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// Manages API keys for channel authentication.
/// Keys are stored as SHA-256 hashes for security.
class ApiKeyManager {
  final Map<String, ApiKeyInfo> _keys = {};
  final String? _storagePath;

  ApiKeyManager({String? storagePath}) : _storagePath = storagePath {
    _loadKeys();
  }

  /// Generate new API key for a channel
  String generateKey(String channelId, {String? name}) {
    final key = _generateSecureKey();
    final hash = _hashKey(key);

    _keys[hash] = ApiKeyInfo(
      channelId: channelId,
      name: name ?? 'default',
      createdAt: DateTime.now(),
    );

    _saveKeys();
    return key;
  }

  /// Validate API key and return channel ID if valid
  String? validateKey(String? key) {
    if (key == null || key.isEmpty) return null;
    final hash = _hashKey(key);
    return _keys[hash]?.channelId;
  }

  /// Validate API key for specific channel
  bool validateKeyForChannel(String? key, String channelId) {
    if (key == null || key.isEmpty) return false;
    final hash = _hashKey(key);
    final info = _keys[hash];
    return info != null && info.channelId == channelId;
  }

  /// Revoke API key
  bool revokeKey(String key) {
    final hash = _hashKey(key);
    if (_keys.containsKey(hash)) {
      _keys.remove(hash);
      _saveKeys();
      return true;
    }
    return false;
  }

  /// List all channels with keys (for debugging)
  List<String> get channels => _keys.values.map((k) => k.channelId).toList();

  /// Total number of registered keys
  int get keyCount => _keys.length;

  String _generateSecureKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return 'dhk_${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  String _hashKey(String key) {
    return sha256.convert(utf8.encode(key)).toString();
  }

  void _loadKeys() {
    if (_storagePath == null) return;

    try {
      final file = File(_storagePath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final data = jsonDecode(content) as Map<String, dynamic>;

        for (final entry in data.entries) {
          _keys[entry.key] = ApiKeyInfo.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    } catch (_) {}
  }

  void _saveKeys() {
    if (_storagePath == null) return;

    try {
      final file = File(_storagePath);
      final dir = file.parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final data = _keys.map((k, v) => MapEntry(k, v.toJson()));
      file.writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }

  void clear() {
    _keys.clear();
    _saveKeys();
  }
}
