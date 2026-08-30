import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/languages.dart';
import '../../../../core/domain/entities/chat_message.dart';
import '../../../../core/providers/ai_assistant_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/error_banner.dart';
import '../widgets/language_selector.dart';
import '../widgets/message_input.dart';
import '../widgets/mic_button.dart';
import '../widgets/processing_indicator.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
          // Scroll to bottom whenever messages change
          if (provider.messages.isNotEmpty) _scrollToBottom();

          return Column(
            children: [
              // Error banner
              if (provider.lastError != null &&
                  provider.state == AssistantState.idle)
                ErrorBanner(
                  error: provider.lastError!,
                  onDismiss: () => provider.clearMessages(),
                ),

              // Chat area
              Expanded(child: _buildChatArea(provider)),

              // Processing / speaking indicator
              if (provider.state == AssistantState.processing ||
                  provider.state == AssistantState.speaking)
                ProcessingIndicator(
                  transcript: provider.currentTranscript,
                  isSpeaking: provider.state == AssistantState.speaking,
                ),

              // Controls
              _buildBottomControls(context, provider),
            ],
          );
        },
      ),
    );
  }

  // ── App bar ─────────────────────────────────────────────────────────────────

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
            child: const Icon(Icons.agriculture, color: Colors.white, size: 22),
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
                  'GeoHarvest Assistant',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
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

  // ── Chat area ────────────────────────────────────────────────────────────────

  Widget _buildChatArea(AIAssistantProvider provider) {
    if (provider.messages.isEmpty) {
      return _buildEmptyState(provider.state == AssistantState.listening);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: provider.messages.length,
      itemBuilder: (context, index) {
        final ChatMessage msg = provider.messages[index];
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
            isListening ? 'Listening…' : 'Tap the mic to speak',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Twi · English · Ewe · Ga · Dagbani',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: allGhanaianLanguages.take(6).map((lang) {
              return Chip(
                label: Text(lang.name, style: const TextStyle(fontSize: 11)),
                backgroundColor: const Color(0xFF1A1A1A),
                side: BorderSide(color: Colors.grey[800]!),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Bottom controls ──────────────────────────────────────────────────────────

  Widget _buildBottomControls(
    BuildContext context,
    AIAssistantProvider provider,
  ) {
    final isListening = provider.state == AssistantState.listening;
    final isBusy = provider.isBusy;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        border: Border(top: BorderSide(color: Colors.grey[850]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Language selector + cancel row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LanguageSelector(
                selectedLanguage: provider.selectedLanguage,
                onLanguageSelected: provider.changeLanguage,
              ),
              if (isBusy)
                TextButton.icon(
                  onPressed: provider.cancel,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Mic + text input row
          Row(
            children: [
              MicButton(
                isListening: isListening,
                isBusy: isBusy,
                onTapDown: isBusy ? null : (_) => provider.startListening(),
                onTapUp: isBusy ? null : (_) => provider.stopListening(),
                onTapCancel: isBusy ? null : provider.cancel,
              ),
              const SizedBox(width: 12),
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

  // ── Dialogs ──────────────────────────────────────────────────────────────────

  void _showClearDialog(BuildContext context, AIAssistantProvider provider) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Clear Chat?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'This will clear the conversation history.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.clearMessages();
              Navigator.pop(ctx);
            },
            child: const Text('Clear',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
