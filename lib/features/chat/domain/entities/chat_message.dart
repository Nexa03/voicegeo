import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  final String id;
  final String text;
  final String? language;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.text,
    this.language,
    required this.isUser,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, text, language, isUser, timestamp];
}
