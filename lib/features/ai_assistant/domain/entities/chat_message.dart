class ChatMessage {
  final String id;
  final String text;
  final String? language;
  final bool isUser;
  final DateTime timestamp;
  final String? audioUrl;

  ChatMessage({
    required this.id,
    required this.text,
    this.language,
    required this.isUser,
    required this.timestamp,
    this.audioUrl,
  });
}
