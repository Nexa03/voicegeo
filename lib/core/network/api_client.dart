import 'package:dio/dio.dart';

class ApiClient {
  final String baseUrl;
  final Dio _dio;

  ApiClient(this.baseUrl)
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl.replaceAll(RegExp(r'/\$'), ''),
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
          ),
        );

  Future<Map<String, dynamic>> postChat(
    String message,
    String language,
    String? conversationId,
  ) async {
    final payload = {
      'message': message,
      'language': language,
      if (conversationId != null) 'conversation_id': conversationId,
    };

    final resp = await _dio.post(
      '/api/v1/ai/chat',
      data: payload,
    );

    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> postVoice(
    String base64Audio,
    String language,
    String audioFormat,
  ) async {
    final payload = {
      'audio': base64Audio,
      'language': language,
      'audio_format': audioFormat,
    };

    final resp = await _dio.post(
      '/api/v1/ai/voice',
      data: payload,
    );

    return Map<String, dynamic>.from(resp.data as Map);
  }
}
