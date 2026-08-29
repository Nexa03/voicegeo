import 'package:flutter/material.dart';

class MicButton extends StatelessWidget {
  final bool isListening;
  final bool isBusy;
  final Function(TapDownDetails)? onTapDown;
  final Function(TapUpDetails)? onTapUp;
  final VoidCallback? onTapCancel;

  const MicButton({
    super.key,
    required this.isListening,
    required this.isBusy,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening
              ? Colors.red
              : isBusy
                  ? Colors.grey[800]
                  : Colors.deepPurple,
          boxShadow: isListening
              ? [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 5)]
              : isBusy
                  ? null
                  : [BoxShadow(color: Colors.deepPurple.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 2)],
        ),
        child: Icon(
          isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}
