import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http';
import '../../../../core/voice/voice_service.dart';
import '../../../../core/voice/voice_router.dart';
import '../../../../core/voice/providers/ghana_nlp_provider.dart';
import '../../../../core/constants/languages.dart';
import '../../domain/entities/chat_message.dart';

enum AssistantState {
  idle,
  listening,
  processing,
  speaking,
}

enum ConversationMode {
  voice,
  text,
  mixed,
}

class AIAssistantProvider extends ChangeNotifier {
  final String apiKey;
  final String backendUrl;
  String selectedLanguage;
  final ConversationMode conversationMode;

  final VoiceRouter voiceRouter;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  AssistantState _state = AssistantState.idle;
  final List<ChatMessage> _messages = [];
  String? _currentTranscript;
  String? _currentResponse;
  String? _detectedLanguage;
  String? _lastError;

  AssistantState get state => _state;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String? get currentTranscript => _currentTranscript;
  String? get currentResponse => _currentResponse;
  String? get detectedLanguage => _detectedLanguage;
  String? get lastError => _lastError;
  bool get isBusy =>
      _state == AssistantState.listening ||
      _state == AssistantState.processing ||
      _state == AssistantState.speaking;

  AIAssistantProvider({
    required this.apiKey,
    required this.backendUrl,
    String? initialLanguage,
    this.conversationMode = ConversationMode.mixed,
  })  : selectedLanguage = initialLanguage ?? defaultLanguage,
        voiceRouter = VoiceRouter(
          primaryASR: GhanaNLPProvider(apiKey: apiKey),
          fallbackASR: GhanaNLPProvider(apiKey: apiKey),
          primaryTTS: GhanaNLPProvider(apiKey: apiKey),
          fallbackTTS: GhanaNLPProvider(apiKey: apiKey),
          primaryTranslation: GhanaNLPProvider(apiKey: apiKey),
          fallbackTranslation: GhanaNLPProvider(apiKey: apiKey),
        ) {
    _initAudio();
    _addWelcomeMessage();
  }

  Future<void> _initAudio() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      id: 'welcome',
      text: 'Kofi. Me rekɔ boa wo. Ka asɛm no.',
      language: 'tw',
      isUser: false,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  Future<void> startListening() async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = path.join(dir.path, 'rec_${DateTime.now().millisecondsSinceEpoch}.mp3');

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: filePath,
      );

      _state = AssistantState.listening;
      _currentTranscript = null;
      _currentResponse = null;
      _detectedLanguage = null;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = 'Mic error: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    final recordedPath = await _audioRecorder.stop();
    if (recordedPath == null) return;

    _state = AssistantState.processing;
    _lastError = null;
    notifyListeners();

    try {
      final audioFile = File(recordedPath);
      final audioBytes = await audioFile.readAsBytes();

      // Try ASR with voice router
      String transcript;
      String detectedLang;
      
      try {
        final asrResult = await voiceRouter.transcribe(
          audioBytes: audioBytes,
          languageHint: selectedLanguage,
          audioFormat: 'mp3',
        );
        transcript = asrResult.text;
        detectedLang = asrResult.detectedLanguage;
      } catch (e) {
        // If ASR fails, use demo mode
        transcript = 'Demo: Me pɛ sɛ metɔn me tomato';
        detectedLang = selectedLanguage;
        _lastError = 'ASR unavailable - using demo mode';
      }

      _currentTranscript = transcript;
      _detectedLanguage = detectedLang;
      selectedLanguage = detectedLang;

      _addMessage(transcript, isUser: true, language: _detectedLanguage);

      // Process with AI
      final aiResponse = await _processWithAI(transcript, _detectedLanguage);
      final responseText = aiResponse['message'] as String? ?? '';

      _currentResponse = responseText;
      _addMessage(responseText, isUser: false, language: _detectedLanguage);

      // Speak response if voice mode
      if (conversationMode != ConversationMode.text && responseText.isNotEmpty) {
        await _speakResponse(responseText);
      }

      _state = AssistantState.idle;
      notifyListeners();
    } catch (e) {
      _addMessage('Error: ${e.toString()}', isUser: false, language: 'en');
      _lastError = e.toString();
      _state = AssistantState.idle;
      notifyListeners();
    }
  }

  Future<void> processTextInput(String text) async {
    if (text.trim().isEmpty) return;

    _addMessage(text, isUser: true, language: selectedLanguage);
    _state = AssistantState.processing;
    _lastError = null;
    notifyListeners();

    try {
      final aiResponse = await _processWithAI(text, selectedLanguage);
      final responseText = aiResponse['message'] as String? ?? '';

      _currentResponse = responseText;
      _addMessage(responseText, isUser: false, language: selectedLanguage);

      if (conversationMode != ConversationMode.text && responseText.isNotEmpty) {
        await _speakResponse(responseText);
      }
    } catch (e) {
      _addMessage('Error: ${e.toString()}', isUser: false, language: 'en');
      _lastError = e.toString();
    } finally {
      _state = AssistantState.idle;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _processWithAI(String message, String? language) async {
    // Try backend first
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/v1/ai/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'message': message,
          'language': language ?? selectedLanguage,
          'conversation_id': null,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // Backend unavailable, use local demo brain
    }

    // Local demo AI brain
    return _demoAIResponse(message, language);
  }

  Map<String, dynamic> _demoAIResponse(String message, String? language) {
    final lower = message.toLowerCase();
    String reply;
    String replyLang = language ?? 'tw';

    if (lower.contains('hello') || lower.contains('hi') || lower.contains('hey')) {
      reply = 'Hello! Me yɛ Kofi. Me rekɔ boa wo. Mepɛ sɛ mehu wo asɛm?';
    } else if (lower.contains('price') || lower.contains('bo') || lower.contains('cost')) {
      reply = 'Tomato bo wɔ Ghana yɛ GH₵5.50 kilo baako. Wopɛ sɛ mekyerɛ wo market prices anaa?';
    } else if (lower.contains('buyer') || lower.contains('tɔ')) {
      reply = 'Mahu buyers abiɛsa wɔ Techiman a wɔpɛ tomato. Ɔbɛn wo paa no wɔ 5 km. Wopɛ sɛ mekyerɛ wo?';
    } else if (lower.contains('transport') || lower.contains('kaboom') || lower.contains('truck')) {
      reply = 'Mahu transporters a wɔwɔ Wenchi. Wɔbɛtumi abɔ wo GH₵200. Wopɛ sɛ mefrɛ wo?';
    } else if (lower.contains('weather') || lower.contains('nsuo') || lower.contains('sun')) {
      reply = 'Nsuo bɛtɔ nnɛ. Wobɛtumi adua wɔ wo farm. Yei yɛ dwuma ma wo crops.';
    } else if (lower.contains('help') || lower.contains('boa') || lower.contains('assist')) {
      reply = 'Mebɔ tumi: 1. Hwehwɛ buyers, 2. Check prices, 3. Find transport, 4. Check weather. Ka asɛm no!';
    } else if (lower.contains('thank') || lower.contains('meda')) {
      reply = 'Yiw! Meda wo ase. Biribi foforo bi?';
    } else {
      reply = 'Menya wo asɛm. Mpɛ meboa wo. Kɔkɔɔ ka asɛm no bio anaa.';
    }

    return {
      'type': 'response',
      'conversation_id': 'demo',
      'message': reply,
      'language': replyLang,
      'detected_intent': 'general_chat',
      'tool_used': null,
      'tool_result': null,
      'requires_confirmation': false,
      'pending_action': null,
      'actions': [],
      'navigation': null,
      'suggested_actions': [],
      'expires_at': null,
    };
  }

  Future<void> _speakResponse(String text) async {
    try {
      _state = AssistantState.speaking;
      notifyListeners();

      final ttsResult = await voiceRouter.synthesize(
        text: text,
        language: selectedLanguage,
      );

      final dir = await getTemporaryDirectory();
      final filePath = path.join(dir.path, 'tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      final file = File(filePath);
      await file.writeAsBytes(ttsResult.audioBytes);

      await _audioPlayer.play(DeviceFileSource(filePath));

      _state = AssistantState.idle;
      notifyListeners();
    } catch (e) {
      // TTS failed silently - text is still shown
      _state = AssistantState.idle;
      notifyListeners();
    }
  }

  void _addMessage(String text, {required bool isUser, String? language}) {
    _messages.add(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      language: language,
      isUser: isUser,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  Future<void> cancel() async {
    await _audioRecorder.stop();
    await _audioPlayer.stop();
    _state = AssistantState.idle;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _currentTranscript = null;
    _currentResponse = null;
    _detectedLanguage = null;
    _lastError = null;
    _addWelcomeMessage();
    notifyListeners();
  }

  void changeLanguage(String code) {
    selectedLanguage = code;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
