import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ai_assistant_provider.dart';
import 'ai_assistant_page.dart';

class AIAssistantScreen extends StatelessWidget {
  const AIAssistantScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    const backendUrl = String.fromEnvironment(
      'GEOHARVEST_BACKEND_URL',
      defaultValue: 'http://10.0.2.2:8000',
    );

    const ghananlpApiKey = String.fromEnvironment(
      'GHANANLP_API_KEY',
      defaultValue: '',
    );

    return ChangeNotifierProvider(
      create: (_) => AIAssistantProvider(
        backendUrl: backendUrl,
        ghananlpApiKey: ghananlpApiKey,
      ),
      child: const AIAssistantPage(),
    );
  }
}
