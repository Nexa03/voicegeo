import 'dart:typed_data';
import 'voice_service.dart';
import '../constants/languages.dart';

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
    try {
      final result = await primaryASR.transcribe(
        audioBytes: audioBytes,
        languageHint: languageHint,
        audioFormat: audioFormat,
      );
      if (result.text.isNotEmpty && result.text.length > 1) {
        return result;
      }
    } catch (e) {
      // Fall through to fallback
    }

    try {
      final result = await fallbackASR.transcribe(
        audioBytes: audioBytes,
        languageHint: languageHint,
        audioFormat: audioFormat,
      );
      if (result.text.isNotEmpty) {
        return result;
      }
    } catch (e) {
      // Fall through
    }

    throw VoiceServiceException(
      'All ASR providers failed',
      isRetryable: false,
    );
  }

  Future<TTSResult> synthesize({
    required String text,
    required String language,
    String? voice,
  }) async {
    final langInfo = getLanguageByCode(language);
    final usePrimary = langInfo?.supportedByGhanaNLP ?? false;

    if (usePrimary) {
      try {
        return await primaryTTS.synthesize(
          text: text,
          language: language,
          voice: voice,
        );
      } catch (e) {
        // Fall through
      }
    }

    try {
      return await fallbackTTS.synthesize(
        text: text,
        language: language,
        voice: voice,
      );
    } catch (e) {
      // Fall through
    }

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
    } catch (e) {
      // Fall through
    }

    try {
      return await fallbackTranslation.translate(
        text: text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
    } catch (e) {
      // Fall through
    }

    throw VoiceServiceException(
      'All translation providers failed',
      isRetryable: true,
    );
  }
}
