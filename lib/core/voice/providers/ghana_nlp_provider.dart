import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import '../exceptions/exceptions.dart';
import '../logging/app_logger.dart';
import 'voice_service.dart';

/// GhanaNLP provider for ASR, TTS, and Translation
class GhanaNLPProvider implements VoiceService {
  final String apiKey;
  final String baseUrl;
  final http.Client client;
  final AppLogger _logger = AppLogger();

  GhanaNLPProvider({
    required this.apiKey,
    this.baseUrl = 'https://translation-api.ghananlp.org',
    http.Client? client,
  }) : client = client ?? http.Client() {
    if (apiKey.isEmpty) {
      throw ConfigurationException(
        message: 'GhanaNLP API key is not configured. '
            'Please set GHANANLP_API_KEY environment variable.',
      );
    }
  }

  @override
  Future<ASRResult> transcribe({
    required List<int> audioBytes,
    String? languageHint,
    String? audioFormat,
  }) async {
    _logger.info('Starting ASR transcription for language: $languageHint');

    final lang = languageHint ?? 'tw';

    if (!_isSupportedLang(lang)) {
      throw LanguageException(
        message: 'Language $lang is not supported by GhanaNLP ASR.',
        languageCode: lang,
      );
    }

    if (audioBytes.isEmpty) {
      throw VoiceException(
        message: 'Audio bytes are empty',
        code: 'EMPTY_AUDIO',
        isRetryable: false,
      );
    }

    final format = (audioFormat ?? 'wav').toLowerCase();
    final contentType = _getContentType(format);
    final url = Uri.parse('$baseUrl/asr/v2/transcribe?language=$lang');

    try {
      _logger.debug('Sending ASR request to: $url');
      final response = await client
          .post(
            url,
            headers: {
              'Content-Type': contentType,
              'Ocp-Apim-Subscription-Key': apiKey,
            },
            body: audioBytes,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        final isRetryable = response.statusCode >= 500;
        _logger.error(
          'ASR failed with status ${response.statusCode}',
          response.body,
        );
        throw NetworkException(
          message: 'ASR failed (${response.statusCode}): ${response.body}',
          statusCode: response.statusCode,
          responseBody: response.body,
          isRetryable: isRetryable,
        );
      }

      final text = response.body.trim();

      if (text.isEmpty) {
        throw VoiceException(
          message: 'ASR returned an empty transcript',
          code: 'EMPTY_TRANSCRIPT',
          isRetryable: true,
        );
      }

      _logger.info('ASR successful: "$text"');

      return ASRResult(
        text: text,
        detectedLanguage: lang,
        confidence: null,
        provider: 'GhanaNLP',
      );
    } on VoiceServiceException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.error('ASR network error', e, stackTrace);
      throw VoiceException(
        message: 'ASR network error: $e',
        code: 'NETWORK_ERROR',
        isRetryable: true,
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<TTSResult> synthesize({
    required String text,
    required String language,
    String? voice,
  }) async {
    _logger.info('Starting TTS synthesis for language: $language');

    if (text.trim().isEmpty) {
      throw VoiceException(
        message: 'Text cannot be empty for TTS',
        code: 'EMPTY_TEXT',
        isRetryable: false,
      );
    }

    if (!_isSupportedLang(language)) {
      throw LanguageException(
        message: 'Language $language is not supported by GhanaNLP TTS.',
        languageCode: language,
      );
    }

    final url = Uri.parse('$baseUrl/tts/v1/tts');

    try {
      _logger.debug('Sending TTS request to: $url');
      final response = await client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Ocp-Apim-Subscription-Key': apiKey,
            },
            body: jsonEncode({
              'text': text,
              'language': language,
              if (voice != null) 'voice': voice,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        final isRetryable = response.statusCode >= 500;
        _logger.error(
          'TTS failed with status ${response.statusCode}',
          response.body,
        );
        throw NetworkException(
          message: 'TTS failed (${response.statusCode}): ${response.body}',
          statusCode: response.statusCode,
          responseBody: response.body,
          isRetryable: isRetryable,
        );
      }

      final audioBytes = response.bodyBytes;
      if (audioBytes.isEmpty) {
        throw VoiceException(
          message: 'TTS returned empty audio bytes',
          code: 'EMPTY_AUDIO',
          isRetryable: true,
        );
      }

      _logger.info('TTS successful: ${audioBytes.length} bytes generated');

      return TTSResult(
        audioBytes: audioBytes,
        provider: 'GhanaNLP',
        voiceUsed: voice,
      );
    } on VoiceServiceException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.error('TTS network error', e, stackTrace);
      throw VoiceException(
        message: 'TTS network error: $e',
        code: 'NETWORK_ERROR',
        isRetryable: true,
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    _logger.info('Starting translation from $sourceLang to $targetLang');

    if (text.trim().isEmpty) {
      return text;
    }

    if (!_isSupportedLang(sourceLang) || !_isSupportedLang(targetLang)) {
      _logger.warning(
        'Unsupported language pair: $sourceLang -> $targetLang',
      );
      return text; // Return original text if translation not supported
    }

    if (sourceLang == targetLang) {
      return text;
    }

    final url = Uri.parse('$baseUrl/v1/translate');

    try {
      _logger.debug('Sending translation request to: $url');
      final response = await client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Ocp-Apim-Subscription-Key': apiKey,
            },
            body: jsonEncode({
              'in': text,
              'lang': '$sourceLang-$targetLang',
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        _logger.error(
          'Translation failed with status ${response.statusCode}',
          response.body,
        );
        return text; // Return original text on error
      }

      final translatedText = response.body.trim();
      _logger.info('Translation successful');
      return translatedText;
    } catch (e, stackTrace) {
      _logger.error('Translation error', e, stackTrace);
      return text; // Return original text on error
    }
  }

  @override
  Future<String> detectLanguage(String text) async {
    // Basic language detection based on common words
    // In production, use GhanaNLP language detection API if available
    _logger.debug('Detecting language for: ${text.substring(0, 50)}...');

    // This is a simplified implementation
    // For production, integrate with actual language detection API
    return 'tw'; // Default to Twi
  }

  bool _isSupportedLang(String lang) {
    return const [
      'tw',
      'yo',
      'gaa',
      'dag',
      'ee',
      'en-GH',
      'ha',
      'fat',
    ].contains(lang);
  }

  String _getContentType(String format) {
    return switch (format) {
      'wav' => 'audio/wav',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'webm' => 'audio/webm',
      _ => 'application/octet-stream',
    };
  }

  void dispose() {
    client.close();
  }
}
