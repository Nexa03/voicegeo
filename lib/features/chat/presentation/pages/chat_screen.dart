import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/ai_assistant_provider.dart';
import 'chat_page.dart';

/// Screen wrapper that instantiates the [AIAssistantProvider] and hands it
/// to [ChatPage].
///
/// All backend configuration comes from [Environment] via the provider
/// constructor — no secrets are stored or embedded here.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AIAssistantProvider(),
      child: const ChatPage(),
    );
  }
}
