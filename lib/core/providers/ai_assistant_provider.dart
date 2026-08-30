import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../config/environment.dart';
import '../constants/languages.dart';
import '../exceptions/exceptions.dart';
import '../logging/app_logger.dart';
import '../voice/providers/ghana_nlp_provider.dart';
import '../voice/voice_router.dart';
import '../../features/chat/domain/entities/chat_message.dart';
import '../../core/ai/gemini_ai_provider.dart';

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
  final String geminiApiKey;

  String selectedLanguage;
  final ConversationMode conversationMode;

  late final VoiceRouter voiceRouter;
  late final GeminiAIProvider aiProvider;

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  AssistantState _state = AssistantState.idle;
  final List<ChatMessage> _messages = [];

  String? _currentTranscript;
  String? _currentResponse;
  String? _detectedLanguage;
  String? _lastError;
  String? _conversationId;

  final AppLogger _logger = AppLogger();

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
    required this.geminiApiKey,
    String? initialLanguage,
    this.conversationMode = ConversationMode.mixed,
  }) : selectedLanguage = initialLanguage ?? defaultLanguage {
    _initialize();
  }

  void _initialize() {
    try {
      final ghanalp = GhanaNLPProvider(apiKey: ghananlpApiKey);

      voiceRouter = VoiceRouter(
        primaryASR: ghanalp,
        fallbackASR: ghanalp,
        primaryTTS: ghanalp,
        fallbackTTS: ghanalp,
        primaryTranslation: ghanalp,
        fallbackTranslation: ghanalp,
      );

      aiProvider = GeminiAIProvider();

      _initAudio();
      _addWelcomeMessage();
      _logger.info('AIAssistantProvider initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize AIAssistantProvider', e, stackTrace);
      _lastError = 'Initialization failed: $e';
      notifyListeners();
    }
  }

  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      _logger.info('Audio player initialized');
    } catch (e) {
      _logger.error('Failed to initialize audio player', e);
    }
  }

  void _addWelcomeMessage() {
    const welcomeMessages = {
      'tw': 'Akwaaba! Me yɛ Kofi. Medaase. Wote sɛn?',
      'en-GH': 'Welcome! I am Kofi. Thank you. How are you?',
      'ee': 'Habadzi! Me yɔ Kofi. Akpe. Alɔ wɔ?',
      'gaa': 'Ojekoo! Me din de Kofi. Oyiwaladonŋ. Oshiwaladonŋ ne?',
      'dag': 'Shindaka! N̍maà Kofi. Akpe. Na wa?',
    };

    final message = welcomeMessages[selectedLanguage] ??
        welcomeMessages['en-GH'] ??
        'Welcome! I am Kofi.';

    _messages.add(
      ChatMessage(
        id: 'welcome',
        text: message,
        language: selectedLanguage,
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  Future<void> startListening() async {
    try {
      _logger.info('Starting voice listening...');
      final hasPermission = await _audioRecorder.hasPermission();

      if (!hasPermission) {
        throw AudioException(
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

      _state = AssistantState.listening;
      _currentTranscript = null;
      _currentResponse = null;
      _detectedLanguage = null;
      _lastError = null;

      _logger.info('Voice listening started');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.error('Failed to start listening', e, stackTrace);
      _state = AssistantState.idle;
      _lastError = 'Microphone error: $e';
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    try {
      _logger.info('Stopping voice listening...');
      final recordedPath = await _audioRecorder.stop();

      if (recordedPath == null) {
        _state = AssistantState.idle;
        notifyListeners();
        return;
      }

      _state = AssistantState.processing;
      _lastError = null;
      notifyListeners();

      final audioFile = File(recordedPath);

      if (!await audioFile.exists()) {
        throw AudioException(
          message: 'Recorded audio file does not exist.',
        );
      }

      final audioBytes = await audioFile.readAsBytes();

      if (audioBytes.isEmpty) {
        throw AudioException(
          message: 'Recorded audio is empty.',
        );
      }

      _logger.info('Processing ${audioBytes.length} bytes of audio');

      final asrResult = await voiceRouter.transcribe(
        audioBytes: audioBytes,
        languageHint: selectedLanguage,
        audioFormat: 'wav',
      );

      final transcript = asrResult.text.trim();

      if (transcript.isEmpty) {
        throw VoiceException(
          message: 'I could not understand the recording.',
          code: 'EMPTY_TRANSCRIPT',
          isRetryable: true,
        );
      }

      final detectedLang = asrResult.detectedLanguage.isNotEmpty
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

      final aiResponse = await aiProvider.chatWithFallback(
        transcript,
        language: detectedLang,
      );

      final responseText = aiResponse.trim();

      if (responseText.isEmpty) {
        throw VoiceException(
          message: 'Kofi returned an empty response.',
          code: 'EMPTY_RESPONSE',
          isRetryable: true,
        );
      }

      _currentResponse = responseText;

      _addMessage(
        responseText,
        isUser: false,
        language: detectedLang,
      );

      if (conversationMode != ConversationMode.text &&
          responseText.isNotEmpty) {
        await _speakResponse(
          responseText,
          detectedLang,
        );
      }

      _state = AssistantState.idle;
      _logger.info('Voice processing completed successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.error('Error processing voice', e, stackTrace);
      _state = AssistantState.idle;
      _lastError = e.toString();

      _addMessage(
        'Sorry, I could not process your voice message. Please try again.',
        isUser: false,
        language: 'en-GH',
      );

      notifyListeners();
    } finally {
      try {
        final recordedPath = await _audioRecorder.stop();
        if (recordedPath != null) {
          await File(recordedPath).delete();
        }
      } catch (_) {}
    }
  }

  Future<void> processTextInput(String text) async {
    final cleaned = text.trim();

    if (cleaned.isEmpty || isBusy) {
      return;
    }

    _logger.info('Processing text input: "${cleaned.substring(0, 50)}..."');

    _addMessage(
      cleaned,
      isUser: true,
      language: selectedLanguage,
    );

    _state = AssistantState.processing;
    _lastError = null;
    notifyListeners();

    try {
      final aiResponse = await aiProvider.chatWithFallback(
        cleaned,
        language: selectedLanguage,
      );

      final responseText = aiResponse.trim();

      if (responseText.isEmpty) {
        throw VoiceException(
          message: 'Kofi returned an empty response.',
          code: 'EMPTY_RESPONSE',
          isRetryable: true,
        );
      }

      _currentResponse = responseText;

      _addMessage(
        responseText,
        isUser: false,
        language: selectedLanguage,
      );

      if (conversationMode != ConversationMode.text &&
          responseText.isNotEmpty) {
        await _speakResponse(
          responseText,
          selectedLanguage,
        );
      }

      _logger.info('Text processing completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Error processing text', e, stackTrace);
      _lastError = e.toString();

      _addMessage(
        'Sorry, something went wrong. Please try again.',
        isUser: false,
        language: 'en-GH',
      );
    } finally {
      _state = AssistantState.idle;
      notifyListeners();
    }
  }

  Future<void> _speakResponse(
    String text,
    String language,
  ) async {
    try {
      _logger.info('Starting TTS for response in language: $language');
      _state = AssistantState.speaking;
      notifyListeners();

      final ttsResult = await voiceRouter.synthesize(
        text: text,
        language: language,
      );

      if (ttsResult.audioBytes.isEmpty) {
        throw VoiceException(
          message: 'TTS returned empty audio.',
          code: 'EMPTY_AUDIO',
          isRetryable: true,
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
      await _audioPlayer.play(DeviceFileSource(filePath));
      await _audioPlayer.onPlayerComplete.first;

      _logger.info('TTS playback completed');

      try {
        await file.delete();
      } catch (_) {}
    } catch (e, stackTrace) {
      _logger.error('Voice playback failed', e, stackTrace);
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
        id: DateTime.now().microsecondsSinceEpoch.toString(),
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
      await _audioPlayer.stop();
      _logger.info('Operation cancelled');
    } catch (e) {
      _logger.error('Error during cancel', e);
    }

    _state = AssistantState.idle;
    notifyListeners();
  }

  void clearMessages() {
    _logger.info('Clearing all messages');
    _messages.clear();

    _currentTranscript = null;
    _currentResponse = null;
    _detectedLanguage = null;
    _lastError = null;
    _conversationId = null;

    aiProvider.resetConversation();
    _addWelcomeMessage();
  }

  void changeLanguage(String code) {
    if (isLanguageSupported(code)) {
      selectedLanguage = code;
      _logger.info('Language changed to: $code');
      notifyListeners();
    } else {
      _logger.warning('Unsupported language: $code');
    }
  }

  @override
  void dispose() {
    _logger.info('Disposing AIAssistantProvider');
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    aiProvider.dispose();
    super.dispose();
  }
}
