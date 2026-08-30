import 'package:flutter/material.dart';
import '../../../../core/logging/app_logger.dart';

class ErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback? onDismiss;

  const ErrorBanner({
    Key? key,
    required this.error,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLogger().error('Displaying error banner: $error');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.red.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, color: Colors.orange, size: 18),
            ),
        ],
      ),
    );
  }
}
