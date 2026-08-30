import 'dart:typed_data';
import '../exceptions/exceptions.dart';
import '../logging/app_logger.dart';
import 'voice_service.dart';

/// VoiceRouter manages fallback between primary and fallback voice providers
class VoiceRouter {
  final VoiceService primaryASR;
  final VoiceService fallbackASR;

  final VoiceService primaryTTS;
  final VoiceService fallbackTTS;

  final VoiceService primaryTranslation;
  final VoiceService fallbackTranslation;

  final AppLogger _logger = AppLogger();

  VoiceRouter({
    required this.primaryASR,
    required this.fallbackASR,
    required this.primaryTTS,
    required this.fallbackTTS,
    required this.primaryTranslation,
    required this.fallbackTranslation,
  });

  /// Transcribe audio with fallback support
  Future<ASRResult> transcribe({
    required List<int> audioBytes,
    String? languageHint,
    String? audioFormat,
  }) async {
    _logger.info('Starting transcription (primary ASR)');
    VoiceServiceException? primaryError;

    try {
      final result = await primaryASR.transcribe(
        audioBytes: audioBytes,
        languageHint: languageHint,
        audioFormat: audioFormat,
      );

      if (result.text.trim().isNotEmpty) {
        _logger.info('Primary ASR succeeded');
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
      _logger.warning('Primary ASR failed: $primaryError');
    }

    _logger.info('Attempting fallback ASR');
    try {
      final result = await fallbackASR.transcribe(
        audioBytes: audioBytes,
        languageHint: languageHint,
        audioFormat: audioFormat,
      );

      if (result.text.trim().isNotEmpty) {
        _logger.info('Fallback ASR succeeded');
        return result;
      }
    } catch (e) {
      _logger.error('Fallback ASR also failed: $e');
    }

    _logger.error('All ASR providers failed');
    throw VoiceServiceException(
      'All ASR providers failed. ${primaryError?.message ?? ''}'.trim(),
      isRetryable: primaryError?.isRetryable ?? false,
    );
  }

  /// Synthesize speech with fallback support
  Future<TTSResult> synthesize({
    required String text,
    required String language,
    String? voice,
  }) async {
    _logger.info('Starting TTS synthesis (primary TTS)');
    try {
      final result = await primaryTTS.synthesize(
        text: text,
        language: language,
        voice: voice,
      );
      _logger.info('Primary TTS succeeded');
      return result;
    } catch (e) {
      _logger.warning('Primary TTS failed: $e');
    }

    _logger.info('Attempting fallback TTS');
    try {
      final result = await fallbackTTS.synthesize(
        text: text,
        language: language,
        voice: voice,
      );
      _logger.info('Fallback TTS succeeded');
      return result;
    } catch (e) {
      _logger.error('Fallback TTS also failed: $e');
    }

    _logger.error('All TTS providers failed for language: $language');
    throw VoiceServiceException(
      'All TTS providers failed for language: $language',
      isRetryable: false,
    );
  }

  /// Translate text with fallback support
  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    _logger.info('Starting translation ($sourceLang -> $targetLang)');
    try {
      final result = await primaryTranslation.translate(
        text: text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
      _logger.info('Primary translation succeeded');
      return result;
    } catch (e) {
      _logger.warning('Primary translation failed: $e');
    }

    _logger.info('Attempting fallback translation');
    try {
      final result = await fallbackTranslation.translate(
        text: text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
      _logger.info('Fallback translation succeeded');
      return result;
    } catch (e) {
      _logger.error('Fallback translation also failed: $e');
    }

    _logger.error('All translation providers failed');
    throw VoiceServiceException(
      'All translation providers failed.',
      isRetryable: true,
    );
  }
}
