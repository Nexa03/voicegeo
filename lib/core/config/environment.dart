import 'package:flutter/foundation.dart';

class Environment {
  static const String ghanalp_api_key =
      String.fromEnvironment('GHANANLP_API_KEY', defaultValue: '');
  static const String ghanalp_base_url = String.fromEnvironment(
    'GHANANLP_BASE_URL',
    defaultValue: 'https://translation-api.ghananlp.org',
  );

  static const String backend_url =
      String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:8000');
  static const String backend_api_version =
      String.fromEnvironment('BACKEND_API_VERSION', defaultValue: 'v1');

  static const String gemini_api_key =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static const String app_env =
      String.fromEnvironment('APP_ENV', defaultValue: 'development');
  static const String log_level =
      String.fromEnvironment('LOG_LEVEL', defaultValue: 'info');

  static bool isProduction => app_env == 'production';
  static bool isDevelopment => app_env == 'development';
  static bool isStaging => app_env == 'staging';

  static void validate() {
    if (ghanalp_api_key.isEmpty) {
      throw Exception(
        'GHANANLP_API_KEY is not configured. '
        'Please set it via dart-define or environment variables.',
      );
    }
    if (gemini_api_key.isEmpty && !isDevelopment) {
      throw Exception(
        'GEMINI_API_KEY is required for production deployments.',
      );
    }
  }
}
