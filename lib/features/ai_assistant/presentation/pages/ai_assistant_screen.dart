import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_assistant_provider.dart';
import 'ai_assistant_page.dart';

class AIAssistantScreen extends StatelessWidget {
  const AIAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AIAssistantProvider(
        apiKey: 'YOUR_GHANANLP_API_KEY',
        backendUrl: 'http://localhost:8000',
      ),
      child: const AIAssistantPage(),
    );
  }
}
