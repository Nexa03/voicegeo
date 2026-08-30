import 'package:flutter/material.dart';

class MicButton extends StatelessWidget {
  final bool isListening;
  final bool isBusy;
  final GestureDragDownCallback? onTapDown;
  final GestureDragUpCallback? onTapUp;
  final VoidCallback? onTapCancel;

  const MicButton({
    Key? key,
    required this.isListening,
    required this.isBusy,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragDown: onTapDown,
      onVerticalDragUp: onTapUp,
      onVerticalDragCancel: onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening
              ? Colors.red.withValues(alpha: 0.8)
              : Colors.deepPurple,
          boxShadow: [
            BoxShadow(
              color: isListening
                  ? Colors.red.withValues(alpha: 0.5)
                  : Colors.deepPurple.withValues(alpha: 0.3),
              blurRadius: isListening ? 20 : 10,
              spreadRadius: isListening ? 2 : 0,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isListening)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(seconds: 1),
                builder: (context, value, child) {
                  return Container(
                    width: 60 + (value * 20),
                    height: 60 + (value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3 * (1 - value)),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            Icon(
              isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
