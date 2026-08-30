/// Abstract base class for voice services (ASR, TTS, Translation)
abstract class VoiceService {
  /// Transcribe audio bytes to text
  Future<ASRResult> transcribe({
    required List<int> audioBytes,
    String? languageHint,
    String? audioFormat,
  });

  /// Convert text to speech
  Future<TTSResult> synthesize({
    required String text,
    required String language,
    String? voice,
  });

  /// Translate text between languages
  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  });

  /// Detect language from text
  Future<String> detectLanguage(String text);
}

class ASRResult {
  final String text;
  final String detectedLanguage;
  final double? confidence;
  final String? provider;

  ASRResult({
    required this.text,
    required this.detectedLanguage,
    this.confidence,
    this.provider,
  });
}

class TTSResult {
  final List<int> audioBytes;
  final String? provider;
  final String? voiceUsed;

  TTSResult({
    required this.audioBytes,
    this.provider,
    this.voiceUsed,
  });
}

class VoiceServiceException implements Exception {
  final String message;
  final String? provider;
  final bool isRetryable;
  final Exception? originalException;

  VoiceServiceException(
    this.message, {
    this.provider,
    this.isRetryable = true,
    this.originalException,
  });

  @override
  String toString() => 'VoiceServiceException: $message (provider: $provider)';
}
