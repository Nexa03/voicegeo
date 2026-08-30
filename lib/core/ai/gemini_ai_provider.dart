import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/config/environment.dart';
import '../../core/exceptions/exceptions.dart';
import '../../core/logging/app_logger.dart';

/// Google Gemini AI provider for intelligent responses
class GeminiAIProvider {
  late final GenerativeModel _model;
  late final ChatSession _chatSession;
  final AppLogger _logger = AppLogger();

  String _conversationContext = '';

  GeminiAIProvider() {
    if (Environment.gemini_api_key.isEmpty) {
      throw ConfigurationException(
        message: 'GEMINI_API_KEY is not configured. '
            'Please set it via dart-define or environment variables.',
      );
    }

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: Environment.gemini_api_key,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 500,
      ),
    );

    _chatSession = _model.startChat();
    _initializeContext();
  }

  void _initializeContext() {
    _conversationContext = '''You are Kofi, a helpful agricultural AI assistant for Ghanaian farmers. 
Your purpose is to:
1. Help farmers with agricultural advice
2. Provide market information
3. Assist with farming techniques and crop management
4. Help navigate the GeoHarvest agricultural marketplace
5. Provide information in Ghanaian languages (Twi, Ewe, Ga, Dagbani, etc.)

Always be respectful, clear, and provide practical advice. Keep responses concise but helpful.''';
  }

  Future<String> chat(
    String message, {
    String? language,
    String? context,
  }) async {
    _logger.info('Sending message to Gemini: "${message.substring(0, 50)}..."');

    try {
      final systemPrompt = '''$_conversationContext
Current language: ${language ?? 'English'}
User message: $message
${context != null ? 'Context: $context' : ''}

Respond helpfully and naturally. If the user speaks in a Ghanaian language, 
respond in the same language when possible.''';

      final response = await _chatSession.sendMessage(
        Content.text(systemPrompt),
      );

      final text = response.text ?? '';

      if (text.isEmpty) {
        throw VoiceException(
          message: 'Gemini returned an empty response',
          code: 'EMPTY_RESPONSE',
          isRetryable: true,
        );
      }

      _logger.info('Gemini response received: ${text.substring(0, 50)}...');
      return text;
    } catch (e, stackTrace) {
      _logger.error('Gemini API error', e, stackTrace);
      throw VoiceException(
        message: 'Failed to get response from AI: $e',
        code: 'AI_ERROR',
        isRetryable: true,
        originalException: e is Exception ? e : null,
      );
    }
  }

  Future<String> chatWithFallback(
    String message, {
    String? language,
    String? context,
  }) async {
    try {
      return await chat(
        message,
        language: language,
        context: context,
      );
    } catch (e) {
      _logger.error('Gemini failed, returning fallback response', e);
      return _getFallbackResponse(message, language);
    }
  }

  String _getFallbackResponse(String message, String? language) {
    final responses = {
      'tw': [
        'Akwaaba! Medaase pa. Mate yoo.',
        'Eoo, maakye. Wote sɛn?',
        'Yoo, anka maakye do. Medaase!',
      ],
      'en-GH': [
        'Hello! Thank you. I appreciate that.',
        'Yes, good morning. How are you?',
        'Alright, good morning. Thank you!',
      ],
      'ee': [
        'Habadzi! Akpe! Akpe plee!',
        'Ɛ̃, fɔ̃ŋ. Alɔ wɔ?',
        'Ɛ̃, fɔ̃ŋ wɔ. Akpe!',
      ],
    };

    final lang = language ?? 'en-GH';
    final responseList = responses[lang] ?? responses['en-GH']!;
    return responseList[DateTime.now().microsecond % responseList.length];
  }

  void resetConversation() {
    _chatSession = _model.startChat();
    _logger.info('Conversation reset');
  }

  void dispose() {
    // Gemini API client cleanup if needed
    _logger.info('GeminiAIProvider disposed');
  }
}
