import 'package:flutter/material.dart';

class ErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback? onDismiss;

  const ErrorBanner({
    super.key,
    required this.error,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.red.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.orange),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
