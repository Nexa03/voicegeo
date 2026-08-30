import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class ProcessingIndicator extends StatelessWidget {
  final String message;
  final bool showAnimation;

  const ProcessingIndicator({
    Key? key,
    this.message = 'Processing...',
    this.showAnimation = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAnimation)
            SizedBox(
              width: 50,
              height: 50,
              child: Lottie.asset(
                'assets/animations/loading.json',
                repeat: true,
                reverse: false,
              ),
            )
          else
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
