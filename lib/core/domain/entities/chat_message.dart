import 'package:equatable/equatable.dart';

/// Unified immutable chat message entity.
///
/// Used across the entire GeoHarvest application — chat UI, state provider,
/// and any future persistence layer.
class ChatMessage extends Equatable {
  final String id;
  final String text;

  /// BCP-47 language code, e.g. 'tw', 'en-GH', 'gaa'.
  final String? language;

  /// true  = sent by the local user
  /// false = sent by Kofi (AI)
  final bool isUser;

  final DateTime timestamp;

  /// Optional base64-encoded audio bytes for TTS playback.
  final String? audioBase64;

  /// MIME type for [audioBase64], e.g. 'audio/mpeg'.
  final String? audioMimeType;

  const ChatMessage({
    required this.id,
    required this.text,
    this.language,
    required this.isUser,
    required this.timestamp,
    this.audioBase64,
    this.audioMimeType,
  });

  // ── JSON ────────────────────────────────────────────────────────────────────

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      language: json['language'] as String?,
      isUser: json['is_user'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      audioBase64: json['audio_base64'] as String?,
      audioMimeType: json['audio_mime_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'language': language,
        'is_user': isUser,
        'timestamp': timestamp.toIso8601String(),
        'audio_base64': audioBase64,
        'audio_mime_type': audioMimeType,
      };

  // ── Equatable ───────────────────────────────────────────────────────────────

  @override
  List<Object?> get props => [
        id,
        text,
        language,
        isUser,
        timestamp,
        audioBase64,
        audioMimeType,
      ];

  @override
  String toString() =>
      'ChatMessage(id: $id, isUser: $isUser, lang: $language, '
      'text: "${text.length > 40 ? '${text.substring(0, 40)}…' : text}")';
}
