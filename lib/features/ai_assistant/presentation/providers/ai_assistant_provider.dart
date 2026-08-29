import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/voice/voice_router.dart';
import '../../../../core/voice/providers/ghana_nlp_provider.dart';
import '../../../../core/voice/voice_service.dart';
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
  final String backendUrl;
  final String ghananlpApiKey;

  String selectedLanguage;
  final ConversationMode conversationMode;

  late final VoiceRouter voiceRouter;

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  AssistantState _state = AssistantState.idle;

  final List<ChatMessage> _messages = [];

  String? _currentTranscript;
  String? _currentResponse;
  String? _detectedLanguage;
  String? _lastError;

  String? _conversationId;

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
    required this.backendUrl,
    required this.ghananlpApiKey,
    String? initialLanguage,
    this.conversationMode = ConversationMode.mixed,
  }) : selectedLanguage = initialLanguage ?? defaultLanguage {
    final provider = GhanaNLPProvider(
      apiKey: ghananlpApiKey,
    );

    voiceRouter = VoiceRouter(
      primaryASR: provider,
      fallbackASR: provider,
      primaryTTS: provider,
      fallbackTTS: provider,
      primaryTranslation: provider,
      fallbackTranslation: provider,
    );

    _initAudio();
    _addWelcomeMessage();
  }

  Future<void> _initAudio() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  void _addWelcomeMessage() {
    _messages.add(
      ChatMessage(
        id: 'welcome',
        text: 'Akwaaba! Me yɛ Kofi. Ka asɛm no.',
        language: 'tw',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  Future<void> startListening() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();

      if (!hasPermission) {
        throw Exception(
          'Microphone permission was not granted.',
        );
      }

      final dir = await getTemporaryDirectory();

      final filePath = path.join(
        dir.path,
        'voice_${DateTime.now().millisecondsSinceEpoch}.wav',
      );

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
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
      _state = AssistantState.idle;
      _lastError = 'Microphone error: $e';
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    final recordedPath = await _audioRecorder.stop();

    if (recordedPath == null) {
      _state = AssistantState.idle;
      notifyListeners();
      return;
    }

    _state = AssistantState.processing;
    _lastError = null;

    notifyListeners();

    try {
      final audioFile = File(recordedPath);

      if (!await audioFile.exists()) {
        throw Exception('Recorded audio file does not exist.');
      }

      final audioBytes = await audioFile.readAsBytes();

      if (audioBytes.isEmpty) {
        throw Exception('Recorded audio is empty.');
      }

      final asrResult = await voiceRouter.transcribe(
        audioBytes: audioBytes,
        languageHint: selectedLanguage,
        audioFormat: 'wav',
      );

      final transcript = asrResult.text.trim();

      if (transcript.isEmpty) {
        throw Exception(
          'I could not understand the recording.',
        );
      }

      final detectedLang =
          asrResult.detectedLanguage.isNotEmpty
              ? asrResult.detectedLanguage
              : selectedLanguage;

      _currentTranscript = transcript;
      _detectedLanguage = detectedLang;
      selectedLanguage = detectedLang;

      _addMessage(
        transcript,
        isUser: true,
        language: detectedLang,
      );

      final aiResponse = await _processWithAI(
        transcript,
        detectedLang,
      );

      final responseText =
          aiResponse['message'] as String? ?? '';

      if (responseText.trim().isEmpty) {
        throw Exception(
          'Kofi returned an empty response.',
        );
      }

      _currentResponse = responseText;

      _addMessage(
        responseText,
        isUser: false,
        language: detectedLang,
      );

      if (
        conversationMode != ConversationMode.text &&
        responseText.trim().isNotEmpty
      ) {
        await _speakResponse(
          responseText,
          detectedLang,
        );
      }

      _state = AssistantState.idle;
      notifyListeners();
    } catch (e) {
      _state = AssistantState.idle;

      _lastError = e.toString();

      _addMessage(
        'Sorry, I could not process your voice message.',
        isUser: false,
        language: 'en-GH',
      );

      notifyListeners();
    } finally {
      try {
        await File(recordedPath).delete();
      } catch (_) {}
    }
  }

  Future<void> processTextInput(String text) async {
    final cleaned = text.trim();

    if (cleaned.isEmpty || isBusy) {
      return;
    }

    _addMessage(
      cleaned,
      isUser: true,
      language: selectedLanguage,
    );

    _state = AssistantState.processing;
    _lastError = null;

    notifyListeners();

    try {
      final aiResponse = await _processWithAI(
        cleaned,
        selectedLanguage,
      );

      final responseText =
          aiResponse['message'] as String? ?? '';

      if (responseText.trim().isEmpty) {
        throw Exception(
          'Kofi returned an empty response.',
        );
      }

      _currentResponse = responseText;

      _addMessage(
        responseText,
        isUser: false,
        language: selectedLanguage,
      );

      if (
        conversationMode != ConversationMode.text &&
        responseText.trim().isNotEmpty
      ) {
        await _speakResponse(
          responseText,
          selectedLanguage,
        );
      }
    } catch (e) {
      _lastError = e.toString();

      _addMessage(
        'Sorry, something went wrong while contacting Kofi.',
        isUser: false,
        language: 'en-GH',
      );
    } finally {
      _state = AssistantState.idle;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _processWithAI(
    String message,
    String? language,
  ) async {
    final base = backendUrl.replaceAll(RegExp(r'/$'), '');

    final response = await http
        .post(
          Uri.parse('$base/api/v1/ai/chat'),
          headers: const {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'message': message,
            'language': language ?? selectedLanguage,
            'conversation_id': _conversationId,
          }),
        )
        .timeout(
          const Duration(seconds: 30),
        );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Kofi backend returned '
        '${response.statusCode}: ${response.body}',
      );
    }

    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    _conversationId =
        data['conversation_id'] as String? ??
        _conversationId;

    return data;
  }

  Future<void> _speakResponse(
    String text,
    String language,
  ) async {
    try {
      _state = AssistantState.speaking;
      notifyListeners();

      final ttsResult = await voiceRouter.synthesize(
        text: text,
        language: language,
      );

      if (ttsResult.audioBytes.isEmpty) {
        throw Exception(
          'TTS returned empty audio.',
        );
      }

      final dir = await getTemporaryDirectory();

      final filePath = path.join(
        dir.path,
        'tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );

      final file = File(filePath);

      await file.writeAsBytes(
        ttsResult.audioBytes,
        flush: true,
      );

      await _audioPlayer.stop();

      await _audioPlayer.play(
        DeviceFileSource(filePath),
      );

      await _audioPlayer.onPlayerComplete.first;

      try {
        await file.delete();
      } catch (_) {}
    } catch (e) {
      _lastError = 'Voice playback failed: $e';
    } finally {
      _state = AssistantState.idle;
      notifyListeners();
    }
  }

  void _addMessage(
    String text, {
    required bool isUser,
    String? language,
  }) {
    _messages.add(
      ChatMessage(
        id: DateTime.now()
            .microsecondsSinceEpoch
            .toString(),
        text: text,
        language: language,
        isUser: isUser,
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  Future<void> cancel() async {
    try {
      await _audioRecorder.stop();
    } catch (_) {}

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
    _conversationId = null;

    _addWelcomeMessage();
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
