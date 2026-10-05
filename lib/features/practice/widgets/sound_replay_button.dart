import 'package:flutter/material.dart';

/// Три бесплатных повтора стимула. После лимита кнопка гаснет.
class SoundReplayButton extends StatelessWidget {
  const SoundReplayButton({
    super.key,
    required this.remaining,
    required this.onPressed,
  });

  static const freeReplays = 3;

  final int remaining;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final open = remaining > 0 && onPressed != null;
    return OutlinedButton(
      onPressed: open ? onPressed : null,
      child: Text(open ? 'Ещё раз ($remaining)' : 'Повторы кончились'),
    );
  }
}
