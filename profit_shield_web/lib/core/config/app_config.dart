import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AppConfig {
  AppConfig._();

  static const String appName = 'ProfitShield';

  static const String _defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://profitshield.profygen.com/api/v1',
  );

  static const int _defaultIdleTimeoutHours = int.fromEnvironment(
    'IDLE_TIMEOUT_HOURS',
    defaultValue: 3,
  );

  /// DMS API base URL (no trailing slash). Loaded from `app_config.json` on web
  /// so it can be changed in `build/web/app_config.json` without rebuilding.
  static String apiBaseUrl = _normalizeBaseUrl(_defaultApiBaseUrl);

  /// Web idle logout hours. Loaded from `app_config.json` at startup.
  static int idleTimeoutHours = _defaultIdleTimeoutHours;

  static Duration get idleTimeout => Duration(hours: idleTimeoutHours);

  static Future<void> loadRuntimeConfig() async {
    if (!kIsWeb) return;
    try {
      final response = await http.get(_runtimeConfigUri());
      if (response.statusCode != 200 || response.body.isEmpty) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;

      final url = decoded['apiBaseUrl'] ?? decoded['API_BASE_URL'];
      if (url is String && url.trim().isNotEmpty) {
        apiBaseUrl = _normalizeBaseUrl(url);
      }

      final hours = decoded['idleTimeoutHours'];
      if (hours is num && hours > 0) {
        idleTimeoutHours = hours.round();
      }

      if (kDebugMode) {
        debugPrint('API base URL: $apiBaseUrl');
        debugPrint('Idle timeout: $idleTimeoutHours hour(s)');
      }
    } catch (_) {
      // Keep compile-time / default values.
    }
  }

  static String _normalizeBaseUrl(String url) {
    var value = url.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static Uri _runtimeConfigUri() {
    final base = Uri.base;
    final path = base.path;
    final dir = path.endsWith('/')
        ? path
        : path.substring(0, path.lastIndexOf('/') + 1);
    return Uri(
      scheme: base.scheme.isEmpty ? 'http' : base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '${dir}app_config.json',
      queryParameters: {
        't': '${DateTime.now().millisecondsSinceEpoch}',
      },
    );
  }
}
