import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../voice_service.dart';
import '../language_detector.dart';

class GhanaNLPProvider implements VoiceService {
  final String apiKey;
  final String baseUrl;
  final http.Client client;

  GhanaNLPProvider({
    required this.apiKey,
    this.baseUrl = 'https://translation-api.ghananlp.org',
    http.Client? client,
  }) : client = client ?? http.Client();

  @override
  Future<ASRResult> transcribe({
    required Uint8List audioBytes,
    String? languageHint,
    String? audioFormat,
  }) async {
    final lang = languageHint ?? 'tw';

    if (!_isSupportedLang(lang)) {
      throw VoiceServiceException(
        'Language $lang is not supported by GhanaNLP ASR.',
        provider: 'GhanaNLP',
        isRetryable: false,
      );
    }

    if (apiKey.trim().isEmpty) {
      throw VoiceServiceException(
        'GhanaNLP API key is not configured.',
        provider: 'GhanaNLP',
        isRetryable: false,
      );
    }

    final format = (audioFormat ?? 'wav').toLowerCase();

    final contentType = switch (format) {
      'wav' => 'audio/wav',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'webm' => 'audio/webm',
      _ => 'application/octet-stream',
    };

    final url = Uri.parse(
      '$baseUrl/asr/v2/transcribe?language=$lang',
    );

    try {
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
        throw VoiceServiceException(
          'ASR failed (${response.statusCode}): '
          '${response.body}',
          provider: 'GhanaNLP',
          isRetryable: response.statusCode >= 500,
        );
      }

      final text = response.body.trim();

      if (text.isEmpty) {
        throw VoiceServiceException(
          'ASR returned an empty transcript.',
          provider: 'GhanaNLP',
          isRetryable: true,
        );
      }

      return ASRResult(
        text: text,
        detectedLanguage: lang,
        confidence: null,
        provider: 'GhanaNLP',
      );
    } on VoiceServiceException {
      rethrow;
    } catch (e) {
      throw VoiceServiceException(
        'ASR network error: $e',
        provider: 'GhanaNLP',
        isRetryable: true,
      );
    }
  }

  @override
  Future<TTSResult> synthesize({
    required String text,
    required String language,
    String? voice,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw VoiceServiceException(
        'GhanaNLP API key is not configured.',
        provider: 'GhanaNLP',
        isRetryable: false,
      );
    }

    final url = Uri.parse('$baseUrl/tts/v1/tts');

    try {
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
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw VoiceServiceException(
          'TTS failed (${response.statusCode}): '
          '${response.body}',
          provider: 'GhanaNLP',
          isRetryable: response.statusCode >= 500,
        );
      }

      return TTSResult(
        audioBytes: response.bodyBytes,
        provider: 'GhanaNLP',
        voiceUsed: voice,
      );
    } on VoiceServiceException {
      rethrow;
    } catch (e) {
      throw VoiceServiceException(
        'TTS network error: $e',
        provider: 'GhanaNLP',
        isRetryable: true,
      );
    }
  }

  @override
  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw VoiceServiceException(
        'GhanaNLP API key is not configured.',
        provider: 'GhanaNLP',
        isRetryable: false,
      );
    }

    final url = Uri.parse('$baseUrl/v1/translate');

    try {
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
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw VoiceServiceException(
          'Translation failed (${response.statusCode}): '
          '${response.body}',
          provider: 'GhanaNLP',
          isRetryable: response.statusCode >= 500,
        );
      }

      return response.body.trim();
    } on VoiceServiceException {
      rethrow;
    } catch (e) {
      throw VoiceServiceException(
        'Translation network error: $e',
        provider: 'GhanaNLP',
        isRetryable: true,
      );
    }
  }

  @override
  Future<String> detectLanguage(String text) async {
    return LanguageDetector.detect(text, null);
  }

  bool _isSupportedLang(String lang) {
    return const [
      'tw',
      'yo',
      'gaa',
      'dag',
      'ee',
      'en-GH',
    ].contains(lang);
  }

  void dispose() {
    client.close();
  }
}
