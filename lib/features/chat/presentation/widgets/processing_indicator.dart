import 'package:flutter/material.dart';

class ProcessingIndicator extends StatelessWidget {
  final String? transcript;
  final bool isSpeaking;

  const ProcessingIndicator({
    super.key,
    this.transcript,
    this.isSpeaking = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isSpeaking) {
      return _row(
        icon: const Icon(Icons.volume_up, size: 16, color: Colors.deepPurple),
        label: 'Speaking…',
      );
    }

    return _row(
      icon: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
        ),
      ),
      label: transcript != null ? 'Heard: "$transcript"' : 'Processing…',
    );
  }

  Widget _row({required Widget icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
