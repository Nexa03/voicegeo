import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_assistant_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/mic_button.dart';
import '../widgets/message_input.dart';
import '../../../../core/constants/languages.dart';
import '../../domain/entities/chat_message.dart';
import '../../../../core/voice/voice_service.dart';

class AIAssistantPage extends StatelessWidget {
  const AIAssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Kofi',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            _LanguageBadge(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: () => context.read<AIAssistantProvider>().clearMessages(),
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<AIAssistantProvider>(
              builder: (context, provider, _) {
                if (provider.messages.isEmpty) {
                  return _buildEmptyState(provider.state == AssistantState.listening);
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.messages.length,
                  itemBuilder: (context, index) {
                    final msg = provider.messages[index];
                    return ChatBubble(message: msg);
                  },
                );
              },
            ),
          ),
          Consumer<AIAssistantProvider>(
            builder: (context, provider, _) {
              if (provider.lastError != null && provider.state == AssistantState.idle) {
                return _buildErrorBanner(provider.lastError!);
              }
              if (provider.state == AssistantState.processing) {
                return _buildProcessingIndicator(provider);
              }
              if (provider.state == AssistantState.speaking) {
                return _buildSpeakingIndicator();
              }
              return const SizedBox.shrink();
            },
          ),
          _buildBottomControls(context),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.red.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        ],
      ),
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
            'Twi / English / Mixed',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allGhanaianLanguages.take(7).map((lang) {
              return Chip(
                label: Text(lang.name, style: const TextStyle(fontSize: 11)),
                backgroundColor: const Color(0xFF1A1A1A),
                side: BorderSide(color: Colors.grey[800]!),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingIndicator(AIAssistantProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple),
          ),
          const SizedBox(width: 12),
          Text(
            provider.currentTranscript != null
                ? 'Heard: "${provider.currentTranscript}"'
                : 'Processing...',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.volume_up, size: 16, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Text(
            'Speaking...',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    final provider = context.watch<AIAssistantProvider>();
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
      child: Row(
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
          Expanded(child: MessageInput(onSubmitted: provider.processTextInput)),
        ],
      ),
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AIAssistantProvider>();
    final langName = getLanguageDisplayName(provider.selectedLanguage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Text(
        langName,
        style: TextStyle(color: Colors.grey[300], fontSize: 12),
      ),
    );
  }
}
