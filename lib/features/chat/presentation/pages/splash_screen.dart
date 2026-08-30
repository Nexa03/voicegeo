import 'package:flutter/material.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/logging/app_logger.dart';

/// Splash / boot screen.
///
/// Validates the runtime environment and navigates to the '/chat' named route.
/// In development, configuration warnings are logged but do not block launch.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AppLogger _logger = AppLogger();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    _logger.info('Booting GeoHarvest…');

    try {
      Environment.validate();
      _logger.info('Environment OK (${Environment.appEnv})');
    } on EnvironmentException catch (e) {
      // In production this is a hard error; in development just warn.
      _logger.warning('Environment warning: ${e.message}');
      if (Environment.isProduction) {
        if (!mounted) return;
        _showFatalError(e.message);
        return;
      }
    }

    // Brief visual pause so the splash is not a flash.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/chat');
  }

  void _showFatalError(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Configuration Error',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.agriculture,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'GeoHarvest',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Powered by Kofi AI',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
