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
        'Language $lang not supported by GhanaNLP ASR',
        provider: 'GhanaNLP',
        isRetryable: false,
      );
    }

    final url = Uri.parse('$baseUrl/asr/v2/transcribe?language=$lang');

    try {
      final response = await client.post(
        url,
        headers: {
          'Content-Type': 'audio/mpeg',
          'Ocp-Apim-Subscription-Key': apiKey,
        },
        body: audioBytes,
      );

      if (response.statusCode == 200) {
        return ASRResult(
          text: response.body.trim(),
          detectedLanguage: lang,
          confidence: null,
          provider: 'GhanaNLP',
        );
      } else {
        throw VoiceServiceException(
          'ASR failed: ${response.statusCode}',
          provider: 'GhanaNLP',
          isRetryable: true,
        );
      }
    } catch (e) {
      throw VoiceServiceException(
        'ASR error: $e',
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
    final url = Uri.parse('$baseUrl/tts/v1/tts');

    try {
      final response = await client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Ocp-Apim-Subscription-Key': apiKey,
        },
        body: jsonEncode({
          'text': text,
          'language': language,
        }),
      );

      if (response.statusCode == 200) {
        return TTSResult(
          audioBytes: response.bodyBytes,
          provider: 'GhanaNLP',
          voiceUsed: voice,
        );
      } else {
        throw VoiceServiceException(
          'TTS failed: ${response.statusCode}',
          provider: 'GhanaNLP',
          isRetryable: true,
        );
      }
    } catch (e) {
      throw VoiceServiceException(
        'TTS error: $e',
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
    final url = Uri.parse('$baseUrl/v1/translate');

    final response = await client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Ocp-Apim-Subscription-Key': apiKey,
      },
      body: jsonEncode({
        'in': text,
        'lang': '$sourceLang-$targetLang',
      }),
    );

    if (response.statusCode == 200) {
      return response.body.trim();
    } else {
      final error = jsonDecode(response.body);
      throw VoiceServiceException(
        'Translation failed: ${error['message']}',
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
    return const ['tw', 'yo', 'gaa', 'dag', 'ee', 'ki', 'en-GH'].contains(lang);
  }
}
