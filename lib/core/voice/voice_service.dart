import 'dart:typed_data';

class VoiceServiceException implements Exception {
  final String message;
  final String? provider;
  final bool isRetryable;

  const VoiceServiceException(
    this.message, {
    this.provider,
    this.isRetryable = false,
  });

  @override
  String toString() => 'VoiceServiceException: $message';
}

abstract class VoiceService {
  Future<ASRResult> transcribe({
    required Uint8List audioBytes,
    String? languageHint,
    String? audioFormat,
  });

  Future<TTSResult> synthesize({
    required String text,
    required String language,
    String? voice,
  });

  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  });

  Future<String> detectLanguage(String text);
}

class ASRResult {
  final String text;
  final String detectedLanguage;
  final double? confidence;
  final String provider;

  const ASRResult({
    required this.text,
    required this.detectedLanguage,
    this.confidence,
    required this.provider,
  });
}

class TTSResult {
  final Uint8List audioBytes;
  final String provider;
  final String? voiceUsed;

  const TTSResult({
    required this.audioBytes,
    required this.provider,
    this.voiceUsed,
  });
}
