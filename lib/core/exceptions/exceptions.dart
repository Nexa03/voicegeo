/// Typed exception hierarchy for the GeoHarvest application.
///
/// All GeoHarvest exceptions extend [GeoHarvestException] so callers
/// can catch either the base class or a specific subtype.
library;

// ── Base ─────────────────────────────────────────────────────────────────────

abstract class GeoHarvestException implements Exception {
  final String message;
  final bool isRetryable;

  const GeoHarvestException({
    required this.message,
    this.isRetryable = false,
  });

  @override
  String toString() => '$runtimeType: $message';
}

// ── Voice / Audio ─────────────────────────────────────────────────────────────

class VoiceException extends GeoHarvestException {
  final String? code;
  final Exception? originalException;

  const VoiceException({
    required super.message,
    this.code,
    super.isRetryable = false,
    this.originalException,
  });

  @override
  String toString() => 'VoiceException[$code]: $message';
}

class AudioException extends GeoHarvestException {
  final Exception? originalException;

  const AudioException({
    required super.message,
    this.originalException,
  });
}

// ── Network ───────────────────────────────────────────────────────────────────

class NetworkException extends GeoHarvestException {
  final int? statusCode;
  final String? responseBody;

  const NetworkException({
    required super.message,
    this.statusCode,
    this.responseBody,
    super.isRetryable = true,
  });

  @override
  String toString() => 'NetworkException(${statusCode ?? "?"}): $message';
}

// ── Language ─────────────────────────────────────────────────────────────────

class LanguageException extends GeoHarvestException {
  final String? languageCode;

  const LanguageException({
    required super.message,
    this.languageCode,
  });

  @override
  String toString() => 'LanguageException[$languageCode]: $message';
}

// ── Configuration ─────────────────────────────────────────────────────────────

class ConfigurationException extends GeoHarvestException {
  const ConfigurationException({required super.message});
}
