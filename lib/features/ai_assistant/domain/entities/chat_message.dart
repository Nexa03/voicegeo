```dart name=lib/features/ai_assistant/domain/entities/chat_message.dart
class ChatMessage {
  final String id;
  final String text;
  final String role; // 'user' | 'assistant' | 'system'
  final String? language;
  final bool isUser;
  final DateTime timestamp;
  final String? audioUrl;
  final String? type; // 'text' | 'audio' | 'action'
  final String? intent;
  final Map<String, dynamic>? entities;
  final bool requiresConfirmation;
  final Map<String, dynamic>? pendingAction;
  final List<dynamic>? suggestedActions;

  ChatMessage({
    required this.id,
    required this.text,
    this.role = 'assistant',
    this.language,
    required this.isUser,
    required this.timestamp,
    this.audioUrl,
    this.type,
    this.intent,
    this.entities,
    this.requiresConfirmation = false,
    this.pendingAction,
    this.suggestedActions,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'role': role,
        'language': language,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'audioUrl': audioUrl,
        'type': type,
        'intent': intent,
        'entities': entities,
        'requiresConfirmation': requiresConfirmation,
        'pendingAction': pendingAction,
        'suggestedActions': suggestedActions,
      };

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      role: json['role'] as String? ?? 'assistant',
      language: json['language'] as String?,
      isUser: json['isUser'] as bool? ?? false,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      audioUrl: json['audioUrl'] as String?,
      type: json['type'] as String?,
      intent: json['intent'] as String?,
      entities: json['entities'] as Map<String, dynamic>?,
      requiresConfirmation: json['requiresConfirmation'] as bool? ?? false,
      pendingAction: json['pendingAction'] as Map<String, dynamic>?,
      suggestedActions: (json['suggestedActions'] as List<dynamic>?) ?? [],
    );
  }
}
```
