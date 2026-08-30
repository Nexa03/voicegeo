import 'package:flutter/material.dart';

import 'features/chat/presentation/pages/chat_screen.dart';
import 'features/chat/presentation/pages/splash_screen.dart';

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
      // Named routes — SplashScreen navigates to '/chat' after boot validation.
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/chat': (_) => const ChatScreen(),
      },
    );
  }
}
