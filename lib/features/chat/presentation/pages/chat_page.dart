import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/languages.dart';
import '../../../../core/providers/ai_assistant_provider.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/chat_message.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/error_banner.dart';
import '../widgets/language_selector.dart';
import '../widgets/mic_button.dart';
import '../widgets/message_input.dart';
import '../widgets/processing_indicator.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late ScrollController _scrollController;
  final AppLogger _logger = AppLogger();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _logger.info('ChatPage initialized');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: _buildAppBar(context),
      body: Consumer<AIAssistantProvider>(
        builder: (context, provider, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });

          return Column(
            children: [
              if (provider.lastError != null &&
                  provider.state == AssistantState.idle)
                ErrorBanner(
                  error: provider.lastError!,
                  onDismiss: () {
                    // Error will be cleared on next action
                  },
                ),
              Expanded(
                child: _buildChatArea(provider),
              ),
              if (provider.state == AssistantState.processing ||
                  provider.state == AssistantState.speaking)
                _buildStatusIndicator(provider),
              _buildBottomControls(context, provider),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0F0F0F),
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kofi',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Agricultural Assistant',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Consumer<AIAssistantProvider>(
          builder: (context, provider, _) => IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: () => _showClearDialog(context, provider),
            tooltip: 'Clear chat',
          ),
        ),
      ],
    );
  }

  Widget _buildChatArea(AIAssistantProvider provider) {
    if (provider.messages.isEmpty) {
      return _buildEmptyState(provider.state == AssistantState.listening);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: provider.messages.length,
      itemBuilder: (context, index) {
        final msg = provider.messages[index];
        return ChatBubble(message: msg);
      },
    );
  }

  Widget _buildEmptyState(bool isListening) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.deepPurple.withValues(alpha: 0.1),
            ),
            child: Icon(
              isListening ? Icons.mic_rounded : Icons.language_rounded,
              size: 60,
              color: isListening ? Colors.red : Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isListening ? 'Listening...' : 'Tap the mic to speak',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Twi / English / Ewe / Ga / Dagbani',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allGhanaianLanguages.take(5).map((lang) {
              return Chip(
                label: Text(
                  lang.name,
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: const Color(0xFF1A1A1A),
                side: BorderSide(color: Colors.grey[800]!),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(AIAssistantProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (provider.state == AssistantState.processing)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                  ),
                ),
                const SizedBox(width: 12),
                if (provider.currentTranscript != null)
                  Expanded(
                    child: Text(
                      'Heard: "${provider.currentTranscript}"',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  Text(
                    'Processing...',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
              ],
            )
          else if (provider.state == AssistantState.speaking)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.volume_up, size: 18, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  'Speaking...',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(
      BuildContext context, AIAssistantProvider provider) {
    final isListening = provider.state == AssistantState.listening;
    final isProcessing = provider.state == AssistantState.processing;
    final isSpeaking = provider.state == AssistantState.speaking;
    final isBusy = isListening || isProcessing || isSpeaking;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        border: Border(top: BorderSide(color: Colors.grey[850]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LanguageSelector(
                selectedLanguage: provider.selectedLanguage,
                availableLanguages:
                    allGhanaianLanguages.map((l) => l.code).toList(),
                onLanguageSelected: (lang) {
                  provider.changeLanguage(lang);
                  _logger.info('Language changed to: $lang');
                },
                languageNames: {
                  for (var lang in allGhanaianLanguages) lang.code: lang.name
                },
              ),
              if (isBusy)
                TextButton.icon(
                  onPressed: () => provider.cancel(),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MicButton(
                isListening: isListening,
                isBusy: isBusy,
                onTapDown: isBusy ? null : (_) => provider.startListening(),
                onTapUp: isBusy ? null : (_) => provider.stopListening(),
                onTapCancel: isBusy ? null : () => provider.cancel(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MessageInput(
                  onSubmitted: (text) {
                    provider.processTextInput(text);
                    _scrollToBottom();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, AIAssistantProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Clear Chat?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to clear the conversation history?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.clearMessages();
              Navigator.pop(context);
              _logger.info('Chat cleared by user');
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
