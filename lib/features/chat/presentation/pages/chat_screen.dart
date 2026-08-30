import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/environment.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/providers/ai_assistant_provider.dart';
import 'chat_page.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AIAssistantProvider(
        backendUrl: Environment.backend_url,
        ghananlpApiKey: Environment.ghanalp_api_key,
        geminiApiKey: Environment.gemini_api_key,
      ),
      child: const ChatPage(),
    );
  }
}
