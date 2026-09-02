class AppConfig {
  AppConfig._();

  /// DMS API base URL (no trailing slash).
  /// Override: `--dart-define=API_BASE_URL=http://localhost:5000/api/v1`
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'https://profitshield.profygen.com/api/v1';
    // return 'http://192.168.10.162:5000/api/v1';
  }

  static const String appName = 'ProfitShield';
}
