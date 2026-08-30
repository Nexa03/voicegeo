// test/widget_test.dart
//
// GeoHarvest Flutter tests.
//
// All tests are self-contained — they do not require network access,
// a running backend, or external API keys.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geoharvest/core/domain/entities/chat_message.dart';
import 'package:geoharvest/core/constants/languages.dart';
import 'package:geoharvest/core/voice/language_detector.dart';
import 'package:geoharvest/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:geoharvest/features/chat/presentation/widgets/error_banner.dart';
import 'package:geoharvest/features/chat/presentation/widgets/processing_indicator.dart';
import 'package:geoharvest/main.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Wrap a widget in MaterialApp + Scaffold so Directionality is available.
Widget wrapWithMaterial(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

// ── Test suite ────────────────────────────────────────────────────────────────

void main() {
  // ── ChatMessage entity ──────────────────────────────────────────────────

  group('ChatMessage entity', () {
    test('creates with required fields', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        id: 'msg-1',
        text: 'Hello Kofi',
        isUser: true,
        timestamp: now,
      );
      expect(msg.id, 'msg-1');
      expect(msg.text, 'Hello Kofi');
      expect(msg.isUser, true);
      expect(msg.language, isNull);
      expect(msg.audioBase64, isNull);
    });

    test('value equality via Equatable', () {
      final ts = DateTime(2026, 1, 1, 12, 0);
      final a = ChatMessage(
        id: 'x',
        text: 'Hi',
        isUser: false,
        timestamp: ts,
        language: 'tw',
      );
      final b = ChatMessage(
        id: 'x',
        text: 'Hi',
        isUser: false,
        timestamp: ts,
        language: 'tw',
      );
      expect(a, equals(b));
    });

    test('different id produces inequality', () {
      final ts = DateTime(2026, 1, 1);
      final a = ChatMessage(id: '1', text: 'Hi', isUser: true, timestamp: ts);
      final b = ChatMessage(id: '2', text: 'Hi', isUser: true, timestamp: ts);
      expect(a, isNot(equals(b)));
    });

    test('JSON round-trip', () {
      final ts = DateTime(2026, 8, 30, 12, 0, 0);
      final msg = ChatMessage(
        id: 'json-1',
        text: 'Test message',
        isUser: true,
        timestamp: ts,
        language: 'en-GH',
      );
      final json = msg.toJson();
      final restored = ChatMessage.fromJson(json);
      expect(restored, equals(msg));
    });

    test('JSON includes audio fields when set', () {
      final msg = ChatMessage(
        id: 'audio-1',
        text: 'Spoken reply',
        isUser: false,
        timestamp: DateTime(2026, 1, 1),
        audioBase64: 'dGVzdA==',
        audioMimeType: 'audio/mpeg',
      );
      final json = msg.toJson();
      expect(json['audio_base64'], 'dGVzdA==');
      expect(json['audio_mime_type'], 'audio/mpeg');
    });
  });

  // ── Language constants ──────────────────────────────────────────────────

  group('Language constants', () {
    test('defaultLanguage is Twi', () {
      expect(defaultLanguage, 'tw');
    });

    test('getLanguageByCode returns correct language', () {
      final lang = getLanguageByCode('tw');
      expect(lang, isNotNull);
      expect(lang!.name, contains('Twi'));
    });

    test('getLanguageByCode returns null for unknown code', () {
      expect(getLanguageByCode('xx-UNKNOWN'), isNull);
    });

    test('allGhanaianLanguages contains at least 5 entries', () {
      expect(allGhanaianLanguages.length, greaterThanOrEqualTo(5));
    });

    test('isLanguageSupported true for known codes', () {
      expect(isLanguageSupported('tw'), isTrue);
      expect(isLanguageSupported('en-GH'), isTrue);
      expect(isLanguageSupported('gaa'), isTrue);
    });

    test('isLanguageSupported false for unknown code', () {
      expect(isLanguageSupported('zz-FAKE'), isFalse);
    });
  });

  // ── Language detector ───────────────────────────────────────────────────

  group('LanguageDetector', () {
    test('detects English from common words', () {
      final lang = LanguageDetector.detect(
        'What is the price of tomatoes in the market today?',
        null,
      );
      expect(lang, 'en-GH');
    });

    test('falls back to defaultLanguage for empty string', () {
      final lang = LanguageDetector.detect('', null);
      expect(lang, defaultLanguage);
    });

    test('falls back to device locale when provided and no match', () {
      // Single character with no language markers
      final lang = LanguageDetector.detect('x', 'dag');
      expect(lang, 'dag');
    });

    test('getByCode returns correct language', () {
      final lang = LanguageDetector.getByCode('ee');
      expect(lang, isNotNull);
      expect(lang!.code, 'ee');
    });

    test('getDisplayName returns code uppercase for unknown', () {
      expect(LanguageDetector.getDisplayName('zz'), 'ZZ');
    });
  });

  // ── ChatBubble widget ───────────────────────────────────────────────────

  group('ChatBubble widget', () {
    testWidgets('renders user message text', (tester) async {
      final msg = ChatMessage(
        id: 'u1',
        text: 'Hello from user',
        isUser: true,
        timestamp: DateTime.now(),
      );
      await tester.pumpWidget(wrapWithMaterial(ChatBubble(message: msg)));
      expect(find.text('Hello from user'), findsOneWidget);
    });

    testWidgets('renders assistant message text', (tester) async {
      final msg = ChatMessage(
        id: 'a1',
        text: 'Akwaaba! Me yɛ Kofi.',
        isUser: false,
        timestamp: DateTime.now(),
        language: 'tw',
      );
      await tester.pumpWidget(wrapWithMaterial(ChatBubble(message: msg)));
      expect(find.text('Akwaaba! Me yɛ Kofi.'), findsOneWidget);
    });
  });

  // ── ErrorBanner widget ──────────────────────────────────────────────────

  group('ErrorBanner widget', () {
    testWidgets('shows error text', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(const ErrorBanner(error: 'Network failure')),
      );
      expect(find.text('Network failure'), findsOneWidget);
    });

    testWidgets('calls onDismiss when close icon tapped', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        wrapWithMaterial(
          ErrorBanner(
            error: 'Test error',
            onDismiss: () => dismissed = true,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(dismissed, isTrue);
    });
  });

  // ── ProcessingIndicator widget ──────────────────────────────────────────

  group('ProcessingIndicator widget', () {
    testWidgets('shows Processing text by default', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(const ProcessingIndicator()),
      );
      expect(find.textContaining('Processing'), findsOneWidget);
    });

    testWidgets('shows Speaking text when isSpeaking is true', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(const ProcessingIndicator(isSpeaking: true)),
      );
      expect(find.textContaining('Speaking'), findsOneWidget);
    });

    testWidgets('shows transcript text when provided', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          const ProcessingIndicator(transcript: 'Medaase'),
        ),
      );
      expect(find.textContaining('Medaase'), findsOneWidget);
    });
  });

  // ── App smoke test ──────────────────────────────────────────────────────

  group('GeoHarvestApp smoke', () {
    testWidgets('app builds and shows SplashScreen', (tester) async {
      await tester.pumpWidget(const GeoHarvestApp());
      // First frame — SplashScreen is visible
      await tester.pump();
      expect(find.text('GeoHarvest'), findsOneWidget);
      // Flush the 600ms delayed timer so no pending timers remain
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('app shows Kofi AI branding on splash', (tester) async {
      await tester.pumpWidget(const GeoHarvestApp());
      await tester.pump();
      expect(find.text('Powered by Kofi AI'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
