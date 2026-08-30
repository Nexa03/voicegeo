/// Centralised environment / runtime configuration for GeoHarvest.
///
/// All values come from `--dart-define` compile-time constants.
/// No secrets are stored here — API keys for AI and voice providers
/// live on the backend only.
///
/// Usage:
///   flutter run --dart-define=BACKEND_URL=https://api.geoharvest.app
class Environment {
  // Private constructor — use static members only.
  Environment._();

  // ── Backend ─────────────────────────────────────────────────────────────────

  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    // Android emulator default; desktop/web use 127.0.0.1 (set via dart-define)
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String backendApiVersion = String.fromEnvironment(
    'BACKEND_API_VERSION',
    defaultValue: 'v1',
  );

  // ── Application ─────────────────────────────────────────────────────────────

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const String logLevel = String.fromEnvironment(
    'LOG_LEVEL',
    defaultValue: 'debug',
  );

  // ── Flags ───────────────────────────────────────────────────────────────────

  static bool get isProduction => appEnv == 'production';
  static bool get isDevelopment => appEnv == 'development';
  static bool get isStaging => appEnv == 'staging';

  // ── Validation ───────────────────────────────────────────────────────────────

  /// Throws [EnvironmentException] only for configuration problems that make
  /// production operation impossible.
  ///
  /// In development, missing optional keys are logged as warnings rather than
  /// hard failures so local development does not require every credential.
  static void validate() {
    if (isProduction) {
      if (!backendUrl.startsWith('https://')) {
        throw EnvironmentException(
          'BACKEND_URL must use HTTPS in production. '
          'Current value does not start with "https://".',
        );
      }
    }
  }
}

/// Thrown when a required environment variable is misconfigured.
class EnvironmentException implements Exception {
  final String message;
  const EnvironmentException(this.message);

  @override
  String toString() => 'EnvironmentException: $message';
}
