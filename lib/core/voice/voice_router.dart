import 'dart:typed_data';

import 'voice_service.dart';

class VoiceRouter {
  final VoiceService primaryASR;
  final VoiceService fallbackASR;

  final VoiceService primaryTTS;
  final VoiceService fallbackTTS;

  final VoiceService primaryTranslation;
  final VoiceService fallbackTranslation;

  VoiceRouter({
    required this.primaryASR,
    required this.fallbackASR,
    required this.primaryTTS,
    required this.fallbackTTS,
    required this.primaryTranslation,
    required this.fallbackTranslation,
  });

  Future<ASRResult> transcribe({
    required Uint8List audioBytes,
    String? languageHint,
    String? audioFormat,
  }) async {
    VoiceServiceException? primaryError;

    try {
      final result = await primaryASR.transcribe(
        audioBytes: audioBytes,
        languageHint: languageHint,
        audioFormat: audioFormat,
      );

      if (result.text.trim().isNotEmpty) {
        return result;
      }
    } catch (e) {
      primaryError = e is VoiceServiceException
          ? e
          : VoiceServiceException(
              e.toString(),
              provider: 'primary',
              isRetryable: true,
            );
    }

    // Skip fallback if it is the same provider as primary
    if (identical(primaryASR, fallbackASR)) {
      throw VoiceServiceException(
        'ASR provider failed.'
        '${primaryError != null ? ' ${primaryError.message}' : ''}',
        isRetryable: false,
      );
    }

    try {
      final result = await fallbackASR.transcribe(
        audioBytes: audioBytes,
        languageHint: languageHint,
        audioFormat: audioFormat,
      );

      if (result.text.trim().isNotEmpty) {
        return result;
      }
    } catch (_) {}

    throw VoiceServiceException(
      'All ASR providers failed.'
      '${primaryError != null ? ' ${primaryError.message}' : ''}',
      isRetryable: false,
    );
  }

  Future<TTSResult> synthesize({
    required String text,
    required String language,
    String? voice,
  }) async {
    try {
      return await primaryTTS.synthesize(
        text: text,
        language: language,
        voice: voice,
      );
    } catch (_) {}

    // Skip fallback if it is the same provider as primary
    if (identical(primaryTTS, fallbackTTS)) {
      throw VoiceServiceException(
        'TTS provider failed for language: $language',
        isRetryable: false,
      );
    }

    try {
      return await fallbackTTS.synthesize(
        text: text,
        language: language,
        voice: voice,
      );
    } catch (_) {}

    throw VoiceServiceException(
      'All TTS providers failed for language: $language',
      isRetryable: false,
    );
  }

  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    try {
      return await primaryTranslation.translate(
        text: text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
    } catch (_) {}

    // Skip fallback if it is the same provider as primary
    if (identical(primaryTranslation, fallbackTranslation)) {
      throw VoiceServiceException(
        'Translation provider failed.',
        isRetryable: true,
      );
    }

    try {
      return await fallbackTranslation.translate(
        text: text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
    } catch (_) {}

    throw VoiceServiceException(
      'All translation providers failed.',
      isRetryable: true,
    );
  }
}
