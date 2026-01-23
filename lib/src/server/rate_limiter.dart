import 'package:shelf/shelf.dart';

/// Rate limiter middleware to prevent DoS attacks.
/// Limits requests per IP address within a time window.
class RateLimiter {
  final int maxRequests;
  final Duration window;
  final Map<String, List<DateTime>> _requests = {};

  RateLimiter({
    this.maxRequests = 100,
    this.window = const Duration(minutes: 1),
  });

  Middleware get middleware => (Handler handler) {
    return (Request request) async {
      final ip = _getClientIp(request);
      final now = DateTime.now();

      _requests.putIfAbsent(ip, () => []);
      _requests[ip]!.removeWhere((t) => now.difference(t) > window);

      if (_requests[ip]!.length >= maxRequests) {
        return Response(
          429,
          body: '{"error": "Too many requests", "retryAfter": 60}',
          headers: {'Content-Type': 'application/json'},
        );
      }

      _requests[ip]!.add(now);
      return handler(request);
    };
  };

  String _getClientIp(Request request) {
    return request.headers['x-forwarded-for']?.split(',').first.trim() ??
        request.headers['x-real-ip'] ??
        'unknown';
  }

  void clear() => _requests.clear();
}
