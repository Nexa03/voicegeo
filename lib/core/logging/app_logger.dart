import 'package:logger/logger.dart';
import '../config/environment.dart';

/// Application-wide structured logger.
///
/// Singleton — call `AppLogger()` anywhere to get the same instance.
///
/// Level names use the logger 2.x API:
///   trace / debug / info / warning / error / fatal
///
/// The active level is controlled by the `LOG_LEVEL` dart-define constant.
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();

  late final Logger _logger;

  factory AppLogger() => _instance;

  AppLogger._internal() {
    _logger = Logger(
      level: _levelFromEnv(),
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  void trace(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.t(message, error: error, stackTrace: stackTrace);

  void debug(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.d(message, error: error, stackTrace: stackTrace);

  void info(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.i(message, error: error, stackTrace: stackTrace);

  void warning(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.w(message, error: error, stackTrace: stackTrace);

  void error(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);

  void fatal(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.f(message, error: error, stackTrace: stackTrace);

  // ── Level resolution ─────────────────────────────────────────────────────────

  static Level _levelFromEnv() {
    switch (Environment.logLevel.toLowerCase()) {
      case 'trace':
        return Level.trace;
      case 'debug':
        return Level.debug;
      case 'info':
        return Level.info;
      case 'warning':
      case 'warn':
        return Level.warning;
      case 'error':
        return Level.error;
      case 'fatal':
        return Level.fatal;
      case 'off':
      case 'nothing':
        return Level.off;
      default:
        return Level.debug;
    }
  }
}
