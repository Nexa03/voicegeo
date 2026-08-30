import 'package:dio/dio.dart';

/// Central HTTP client for the GeoHarvest Flutter application.
///
/// All communication with the FastAPI backend passes through this class.
/// No other HTTP library (http, HttpClient) should be used for backend calls.
///
/// API keys and credentials are NEVER passed from Flutter.
/// The backend holds all provider secrets.
class ApiClient {
  final String baseUrl;
  final Dio _dio;

  ApiClient(this.baseUrl)
      : _dio = Dio(
          BaseOptions(
            baseUrl: _normaliseBaseUrl(baseUrl),
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {'Content-Type': 'application/json'},
          ),
        );

  // ── Chat ────────────────────────────────────────────────────────────────────

  /// Send a text message to Kofi and receive a structured AI response.
  Future<Map<String, dynamic>> postChat({
    required String message,
    required String language,
    String? conversationId,
  }) async {
    final payload = <String, dynamic>{
      'message': message,
      'language': language,
    };
    if (conversationId != null) {
      payload['conversation_id'] = conversationId;
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/ai/chat',
      data: payload,
    );

    return _assertMap(response.data);
  }

  // ── Voice ───────────────────────────────────────────────────────────────────

  /// Send base64-encoded audio to the backend for ASR + AI processing.
  ///
  /// The backend handles GhanaNLP transcription and returns both the
  /// transcript and the AI response.
  Future<Map<String, dynamic>> postVoice({
    required String base64Audio,
    required String language,
    String audioFormat = 'wav',
  }) async {
    final payload = <String, dynamic>{
      'audio': base64Audio,
      'language': language,
      'audio_format': audioFormat,
    };

    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/ai/voice',
      data: payload,
    );

    return _assertMap(response.data);
  }

  // ── Health ──────────────────────────────────────────────────────────────────

  /// Check backend availability.
  Future<Map<String, dynamic>> getHealth() async {
    final response = await _dio.get<Map<String, dynamic>>('/health');
    return _assertMap(response.data);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _normaliseBaseUrl(String base) {
    final trimmed = base.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  Map<String, dynamic> _assertMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: RequestOptions(path: ''),
      message: 'Unexpected response type: ${data.runtimeType}',
    );
  }
}
