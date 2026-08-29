import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/ai_assistant/presentation/pages/ai_assistant_screen.dart';
import 'features/ai_assistant/presentation/providers/ai_assistant_provider.dart';

void main() {
  // Default backend for local development:
  // - Android emulator: 10.0.2.2
  // - iOS simulator / desktop: 127.0.0.1
  final defaultBackend = kIsWeb || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux
      ? 'http://127.0.0.1:8000'
      : 'http://10.0.2.2:8000';

  runApp(GeoHarvestApp(backendUrl: defaultBackend));
}

class GeoHarvestApp extends StatelessWidget {
  final String backendUrl;

  const GeoHarvestApp({super.key, required this.backendUrl});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AIAssistantProvider(
        backendUrl: backendUrl,
        ghananlpApiKey: '', // Leave empty to use mock ASR/TTS in backend (USE_MOCK_SERVICES=true)
      ),
      child: MaterialApp(
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
      ),
    );
  }
}
