import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Prints API traffic to the terminal when running `flutter run` in debug mode.
class ApiLogger {
  ApiLogger._();

  static void logStartup() {
    if (!kDebugMode) return;
    debugPrint('');
    debugPrint('ProfitShield API debug logging is ON (debug builds only).');
    debugPrint('Watch this terminal for request/response details when you login.');
    debugPrint('');
  }

  static void request({
    required String method,
    required Uri uri,
    Object? body,
    bool auth = true,
  }) {
    if (!kDebugMode) return;
    debugPrint('');
    debugPrint('API REQUEST ');
    debugPrint(' $method $uri');
    debugPrint(' Auth header: ${auth ? 'yes' : 'no'}');
    if (body != null) {
      debugPrint(' Body: ${_sanitize(body)}');
    }
   
  }

  static void response({
    required String method,
    required Uri uri,
    required int httpStatus,
    required String body,
    required Duration elapsed,
    bool apiStatus = true,
    String? apiStatusCode,
    String? apiMessage,
  }) {
    if (!kDebugMode) return;

    debugPrint(' API RESPONSE ');
    debugPrint(' $method $uri');
    debugPrint(' HTTP: $httpStatus (${elapsed.inMilliseconds} ms)');
    debugPrint(' API status: $apiStatus | code: ${apiStatusCode ?? '-'}');
    if (apiMessage != null && apiMessage.isNotEmpty) {
      debugPrint('│ API message: $apiMessage');
    }
    debugPrint(' Body: ${_truncate(body)}');

  }

  static void failure({
    required String method,
    required Uri uri,
    required Object error,
    Duration? elapsed,
  }) {
    if (!kDebugMode) return;
    debugPrint('');
    debugPrint(' API ERROR ');
    debugPrint(' $method $uri');
    if (elapsed != null) {
      debugPrint(' Elapsed: ${elapsed.inMilliseconds} ms');
    }
    debugPrint(' Error: $error');
    debugPrint('');
  }

  static String _sanitize(Object body) {
    if (body is Map) {
      final copy = Map<String, dynamic>.from(body);
      for (final key in ['password', 'currentPassword', 'newPassword', 'confirmPassword']) {
        if (copy.containsKey(key)) copy[key] = '***';
      }
      return const JsonEncoder.withIndent('  ').convert(copy);
    }
    if (body is String) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return _sanitize(decoded);
        }
      } catch (_) {}
    }
    return body.toString();
  }

  static String _truncate(String value, [int max = 1000]) {
    final singleLine = value.replaceAll('\n', ' ').trim();
    if (singleLine.length <= max) return singleLine;
    return '${singleLine.substring(0, max)}... [truncated]';
  }
}
