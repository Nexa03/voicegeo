class VoiceException implements Exception {
  final String message;
  final String? code;
  final bool isRetryable;
  final Exception? originalException;

  VoiceException({
    required this.message,
    this.code,
    this.isRetryable = false,
    this.originalException,
  });

  @override
  String toString() => 'VoiceException: $message (code: $code)';
}

class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;
  final bool isRetryable;

  NetworkException({
    required this.message,
    this.statusCode,
    this.responseBody,
    this.isRetryable = true,
  });

  @override
  String toString() =>
      'NetworkException: $message (status: $statusCode)';
}

class AudioException implements Exception {
  final String message;
  final Exception? originalException;

  AudioException({
    required this.message,
    this.originalException,
  });

  @override
  String toString() => 'AudioException: $message';
}

class LanguageException implements Exception {
  final String message;
  final String? languageCode;

  LanguageException({
    required this.message,
    this.languageCode,
  });

  @override
  String toString() =>
      'LanguageException: $message (lang: $languageCode)';
}

class ConfigurationException implements Exception {
  final String message;

  ConfigurationException({required this.message});

  @override
  String toString() => 'ConfigurationException: $message';
}
