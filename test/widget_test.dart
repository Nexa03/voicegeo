import 'package:flutter_test/flutter_test.dart';
import 'package:geoharvest/features/ai_assistant/presentation/pages/ai_assistant_screen.dart';

void main() {
  testWidgets('GeoHarvest app launches', (WidgetTester tester) async {
    await tester.pumpWidget(
      const AIAssistantScreen(),
    );
    expect(find.text('Kofi'), findsOneWidget);
  });
}
