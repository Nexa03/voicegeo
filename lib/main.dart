import 'package:flutter/material.dart';
import 'features/ai_assistant/presentation/pages/ai_assistant_screen.dart';

void main() {
  runApp(const GeoHarvestApp());
}

class GeoHarvestApp extends StatelessWidget {
  const GeoHarvestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoHarvest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Colors.deepPurple,
          surface: const Color(0xFF0F0F0F),
          onSurface: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const AIAssistantScreen(),
    );
  }
}
