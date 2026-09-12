import 'env_config.dart';

class AppConfig {
  AppConfig._();

  static String get apiBaseUrl => EnvConfig.apiBaseUrl;

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
}
