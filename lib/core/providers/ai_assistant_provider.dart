import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../config/environment.dart';
import '../constants/languages.dart';
import '../domain/entities/chat_message.dart';
import '../exceptions/exceptions.dart';
import '../logging/app_logger.dart';
import '../network/api_client.dart';
import '../voice/language_detector.dart';

// ── State enumerations ────────────────────────────────────────────────────────

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

// ── Provider ─────────────────────────────────────────────────────────────────

/// Unified AI assistant state provider for GeoHarvest.
///
/// Architecture:
///   Flutter UI → AIAssistantProvider → ApiClient → FastAPI backend
///                                                      ↓
///                                               Kofi AI orchestration
///                                                      ↓
///                                            GhanaNLP / OpenAI / Gemini
///
/// No AI provider API keys are held in Flutter. All LLM and voice provider
/// credentials live on the backend only.
class AIAssistantProvider extends ChangeNotifier {
  // ── Configuration ──────────────────────────────────────────────────────────
  final String backendUrl;
  final ConversationMode conversationMode;

  // ── Services ───────────────────────────────────────────────────────────────
  late final ApiClient _apiClient;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AppLogger _logger = AppLogger();

  // ── State ──────────────────────────────────────────────────────────────────
  AssistantState _state = AssistantState.idle;
  String _selectedLanguage;
  final List<ChatMessage> _messages = [];

  String? _currentTranscript;
  String? _currentResponse;
  String? _detectedLanguage;
  String? _lastError;
  String? _conversationId;

  // ── Getters ────────────────────────────────────────────────────────────────
  AssistantState get state => _state;
  String get selectedLanguage => _selectedLanguage;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String? get currentTranscript => _currentTranscript;
  String? get currentResponse => _currentResponse;
  String? get detectedLanguage => _detectedLanguage;
  String? get lastError => _lastError;

  bool get isBusy =>
      _state == AssistantState.listening ||
      _state == AssistantState.processing ||
      _state == AssistantState.speaking;

  // ── Constructor ───────────────────────────────────────────────────────────

  AIAssistantProvider({
    String? backendUrl,
    String? initialLanguage,
    this.conversationMode = ConversationMode.mixed,
  })  : backendUrl = backendUrl ?? Environment.backendUrl,
        _selectedLanguage = initialLanguage ?? defaultLanguage {
    _init();
  }

  void _init() {
    try {
      _apiClient = ApiClient(backendUrl);
      _initAudio();
      _addWelcomeMessage();
      _logger.info('AIAssistantProvider initialised — backend: $backendUrl');
    } catch (e, st) {
      _logger.error('AIAssistantProvider init failed', e, st);
      _lastError = 'Initialisation failed: $e';
      notifyListeners();
    }
  }

  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      _logger.warning('Audio player init warning', e);
    }
  }

  void _addWelcomeMessage() {
    const welcomeMessages = {
      'tw': 'Akwaaba! Me yɛ Kofi, wo GeoHarvest assistant. Ka asɛm no.',
      'en-GH': 'Welcome! I am Kofi, your GeoHarvest assistant. How can I help?',
      'ee': 'Habadzi! Me yɔ Kofi, wò GeoHarvest assistant. Alɔ wɔ?',
      'gaa': 'Ojekoo! Me din de Kofi, wò GeoHarvest assistant.',
      'dag': 'Shindaka! N yɔ Kofi, a GeoHarvest assistant.',
    };

    final text = welcomeMessages[_selectedLanguage] ??
        welcomeMessages['en-GH']!;

    _messages.add(ChatMessage(
      id: 'welcome',
      text: text,
      language: _selectedLanguage,
      isUser: false,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  // ── Text input ────────────────────────────────────────────────────────────

  Future<void> processTextInput(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty || isBusy) return;

    _addMessage(cleaned, isUser: true, language: _selectedLanguage);
    _setState(AssistantState.processing);
    _lastError = null;
    notifyListeners();

    try {
      _logger.info('Processing text input (${cleaned.length} chars)');
      final response = await _apiClient.postChat(
        message: cleaned,
        language: _selectedLanguage,
        conversationId: _conversationId,
      );

      _handleAiResponse(response, _selectedLanguage);
    } on NetworkException catch (e, st) {
      _logger.error('Network error during text processing', e, st);
      _setError('Network error: ${e.message}');
    } catch (e, st) {
      _logger.error('Unexpected error during text processing', e, st);
      _setError(e.toString());
    } finally {
      _setState(AssistantState.idle);
    }
  }

  // ── Voice input ───────────────────────────────────────────────────────────

  Future<void> startListening() async {
    try {
      _logger.info('Starting voice recording…');
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        throw const AudioException(
          message: 'Microphone permission was not granted.',
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

      _currentTranscript = null;
      _currentResponse = null;
      _detectedLanguage = null;
      _lastError = null;
      _setState(AssistantState.listening);
      _logger.info('Recording started');
    } catch (e, st) {
      _logger.error('Failed to start recording', e, st);
      _setState(AssistantState.idle);
      _lastError = 'Microphone error: $e';
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    String? recordedPath;
    try {
      _logger.info('Stopping recording…');
      recordedPath = await _audioRecorder.stop();

      if (recordedPath == null) {
        _setState(AssistantState.idle);
        notifyListeners();
        return;
      }

      _setState(AssistantState.processing);
      _lastError = null;
      notifyListeners();

      final audioFile = File(recordedPath);
      if (!await audioFile.exists()) {
        throw const AudioException(message: 'Recorded audio file not found.');
      }

      final audioBytes = await audioFile.readAsBytes();
      if (audioBytes.isEmpty) {
        throw const AudioException(message: 'Recorded audio is empty.');
      }

      _logger.info('Sending ${audioBytes.length} bytes to backend voice endpoint');

      // Detect language offline as a hint; backend may refine it.
      final langHint = LanguageDetector.detect('', _selectedLanguage);
      final base64Audio = base64Encode(audioBytes);

      final response = await _apiClient.postVoice(
        base64Audio: base64Audio,
        language: langHint,
      );

      // Voice response wraps: { transcript, language, ai: ChatResponse }
      final transcript = (response['transcript'] as String?)?.trim() ?? '';
      if (transcript.isEmpty) {
        // Real failure — do not fabricate a transcript
        throw const VoiceException(
          message: 'Speech recognition returned an empty transcript.',
          code: 'EMPTY_TRANSCRIPT',
          isRetryable: true,
        );
      }

      final detectedLang =
          (response['language'] as String?) ?? _selectedLanguage;
      _currentTranscript = transcript;
      _detectedLanguage = detectedLang;
      _selectedLanguage = detectedLang;

      _addMessage(transcript, isUser: true, language: detectedLang);

      final aiPayload = response['ai'] as Map<String, dynamic>?;
      if (aiPayload != null) {
        _handleAiResponse(aiPayload, detectedLang);
      }
    } on VoiceException catch (e, st) {
      _logger.error('Voice processing error', e, st);
      _setError(e.message);
    } on NetworkException catch (e, st) {
      _logger.error('Network error during voice processing', e, st);
      _setError('Network error: ${e.message}');
    } catch (e, st) {
      _logger.error('Unexpected error during voice processing', e, st);
      _setError(e.toString());
    } finally {
      _setState(AssistantState.idle);
      // Clean up temp file
      if (recordedPath != null) {
        try {
          await File(recordedPath).delete();
        } catch (_) {}
      }
    }
  }

  // ── AI response handling ───────────────────────────────────────────────────

  void _handleAiResponse(
    Map<String, dynamic> response,
    String language,
  ) {
    final conversationId = response['conversation_id'] as String?;
    if (conversationId != null) _conversationId = conversationId;

    final responseText = (response['message'] as String?)?.trim() ?? '';
    if (responseText.isEmpty) {
      _logger.warning('Backend returned empty message');
      _setError('Kofi returned an empty response.');
      return;
    }

    _currentResponse = responseText;
    _logger.info('Kofi response received (${responseText.length} chars)');

    // Check for TTS audio included in response
    final audioBase64 = response['audio_base64'] as String?;
    final audioMime = response['audio_mime'] as String?;

    _addMessage(
      responseText,
      isUser: false,
      language: language,
      audioBase64: audioBase64,
      audioMimeType: audioMime,
    );

    // Play TTS if audio was returned; fall back to silent mode gracefully
    if (audioBase64 != null && audioBase64.isNotEmpty) {
      _playAudioBase64(audioBase64);
    }
  }

  // ── Audio playback ────────────────────────────────────────────────────────

  Future<void> _playAudioBase64(String base64Audio) async {
    try {
      _setState(AssistantState.speaking);
      notifyListeners();

      final bytes = base64Decode(base64Audio);
      if (bytes.isEmpty) return;

      final dir = await getTemporaryDirectory();
      final filePath = path.join(
        dir.path,
        'tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(filePath));
      await _audioPlayer.onPlayerComplete.first;

      try {
        await file.delete();
      } catch (_) {}

      _logger.info('TTS playback complete');
    } catch (e, st) {
      _logger.warning('TTS playback failed (non-fatal)', e, st);
      // TTS failure is non-fatal — the text response is already shown
    } finally {
      _setState(AssistantState.idle);
      notifyListeners();
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Future<void> cancel() async {
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    _setState(AssistantState.idle);
    _logger.info('Operation cancelled');
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _currentTranscript = null;
    _currentResponse = null;
    _detectedLanguage = null;
    _lastError = null;
    _conversationId = null;
    _logger.info('Messages cleared');
    _addWelcomeMessage();
  }

  void changeLanguage(String code) {
    if (!isLanguageSupported(code)) {
      _logger.warning('Unsupported language requested: $code');
      return;
    }
    _selectedLanguage = code;
    _logger.info('Language changed to: $code');
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _addMessage(
    String text, {
    required bool isUser,
    String? language,
    String? audioBase64,
    String? audioMimeType,
  }) {
    _messages.add(ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      language: language,
      isUser: isUser,
      timestamp: DateTime.now(),
      audioBase64: audioBase64,
      audioMimeType: audioMimeType,
    ));
    notifyListeners();
  }

  void _setState(AssistantState state) => _state = state;

  void _setError(String message) {
    _lastError = message;
    _addMessage(
      _userFacingError(message),
      isUser: false,
      language: 'en-GH',
    );
    notifyListeners();
  }

  String _userFacingError(String raw) {
    if (raw.contains('EMPTY_TRANSCRIPT')) {
      return 'I could not understand the recording. Please speak clearly and try again.';
    }
    if (raw.contains('Network') || raw.contains('SocketException')) {
      return 'Could not reach the GeoHarvest server. Please check your connection.';
    }
    if (raw.contains('Microphone')) {
      return 'Microphone access is required to use voice input.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _logger.info('AIAssistantProvider disposed');
    super.dispose();
  }
}
