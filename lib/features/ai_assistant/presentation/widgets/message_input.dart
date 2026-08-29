import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final Function(String) onSubmitted;

  const MessageInput({super.key, required this.onSubmitted});

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Type in Twi or English...',
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        suffixIcon: IconButton(
          icon: const Icon(Icons.send_rounded, color: Colors.deepPurple),
          onPressed: () {
            if (_controller.text.trim().isEmpty) return;
            widget.onSubmitted(_controller.text);
            _controller.clear();
          },
        ),
      ),
      onSubmitted: widget.onSubmitted,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
