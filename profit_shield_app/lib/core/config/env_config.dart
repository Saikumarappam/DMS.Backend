import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads runtime configuration from `.env` (see `.env.example`).
class EnvConfig {
  EnvConfig._();

  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    await dotenv.load(fileName: '.env');
    _loaded = true;
  }

  static String get baseUrl =>
      dotenv.env['BASE_URL']?.trim().isNotEmpty == true
          ? dotenv.env['BASE_URL']!.trim().replaceAll(RegExp(r'/+$'), '')
          : 'https://profitshield.profygen.com';

  static String get apiVersion =>
      dotenv.env['API_VERSION']?.trim().isNotEmpty == true
          ? dotenv.env['API_VERSION']!.trim()
          : 'v1';

  static String get apiBaseUrl => '$baseUrl/api/$apiVersion';

  /// Optional static bearer token for debugging. Normal login flow stores token in secure storage.
  static String? get authToken {
    final value = dotenv.env['AUTH_TOKEN']?.trim();
    return value != null && value.isNotEmpty ? value : null;
  }

  static bool get useMockData =>
      dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';
}
