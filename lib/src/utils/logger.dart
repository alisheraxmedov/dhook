import 'dart:io';

/// DHOOK Logger - Colorful and formatted terminal logging utility.
class DLogger {
  static bool _enabled = true;
  static LogLevel _minLevel = LogLevel.debug;

  // ANSI color codes
  static const String _reset = '\x1B[0m';
  static const String _bold = '\x1B[1m';
  static const String _dim = '\x1B[2m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _magenta = '\x1B[35m';
  static const String _cyan = '\x1B[36m';
  static const String _white = '\x1B[37m';
  static const String _bgRed = '\x1B[41m';
  static const String _bgGreen = '\x1B[42m';

  /// Enable or disable logging
  static void setEnabled(bool enabled) => _enabled = enabled;

  /// Set minimum log level
  static void setLevel(LogLevel level) => _minLevel = level;

  /// Debug message (gray)
  static void debug(String message) {
    if (_minLevel.index <= LogLevel.debug.index) {
      _log('$_dim DEBUG $_reset', message, _dim);
    }
  }

  /// Info message (green)
  static void info(String message) {
    if (_minLevel.index <= LogLevel.info.index) {
      _log('$_green INFO  $_reset', message, _white);
    }
  }

  /// Warning message (yellow)
  static void warn(String message) {
    if (_minLevel.index <= LogLevel.warn.index) {
      _log('$_yellow WARN  $_reset', message, _yellow);
    }
  }

  /// Error message (red)
  static void error(String message, [Object? error, StackTrace? stack]) {
    if (_minLevel.index <= LogLevel.error.index) {
      _log('$_red ERROR $_reset', message, _red);
      if (error != null) {
        _log('$_red       $_reset', '$_dim$error$_reset', _dim);
      }
      if (stack != null) {
        _log('$_red       $_reset', '$_dim$stack$_reset', _dim);
      }
    }
  }

  /// Success message (bold green)
  static void success(String message) {
    _log('$_green$_bold  OK   $_reset', message, _green);
  }

  /// Connection status (cyan)
  static void connection(String action, String target) {
    final icon = action.toLowerCase().contains('disconnect') ? '○' : '●';
    _log('$_cyan CONN  $_reset', '$icon $action: $_bold$target$_reset', _cyan);
  }

  /// HTTP request/response logging
  static void http(
    String method,
    String path, {
    int? status,
    String? direction,
  }) {
    final arrow = direction == 'in' ? '←' : '→';
    final methodColor = _getMethodColor(method);
    final statusStr = status != null ? ' ${_getStatusBadge(status)}' : '';
    _log(
      '$_blue HTTP  $_reset',
      '$arrow $methodColor$_bold$method$_reset $path$statusStr',
      _white,
    );
  }

  /// WebSocket message logging
  static void ws(String direction, String channel, [String? type]) {
    final arrow = direction == 'in' ? '←' : '→';
    final typeStr = type != null ? ' [$_dim$type$_reset]' : '';
    _log(
      '$_magenta WS    $_reset',
      '$arrow $_bold$channel$_reset$typeStr',
      _white,
    );
  }

  /// Server startup banner
  static void banner(String name, String version, int port) {
    final line = '$_dim${'─' * 50}$_reset';
    stdout.writeln(line);
    stdout.writeln('  $_bold$_cyan$name$_reset $_dim v$version$_reset');
    stdout.writeln(
      '  $_green●$_reset Running on $_bold$_white http://0.0.0.0:$port$_reset',
    );
    stdout.writeln(line);
  }

  /// Format timestamp [HH:mm:ss]
  static String _timestamp() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return '$_dim$h:$m:$s$_reset';
  }

  /// Get color based on HTTP method
  static String _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return _green;
      case 'POST':
        return _blue;
      case 'PUT':
      case 'PATCH':
        return _yellow;
      case 'DELETE':
        return _red;
      default:
        return _white;
    }
  }

  /// Get colored status badge
  static String _getStatusBadge(int code) {
    if (code >= 200 && code < 300) return '$_bgGreen$_bold $code $_reset';
    if (code >= 400) return '$_bgRed$_bold $code $_reset';
    return '$_yellow$code$_reset';
  }

  /// Core log function
  static void _log(String prefix, String message, String color) {
    if (!_enabled) return;
    stdout.writeln('${_timestamp()} $prefix $message');
  }
}

/// Log levels for filtering
enum LogLevel { debug, info, warn, error }
