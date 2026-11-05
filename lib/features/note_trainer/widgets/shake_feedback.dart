import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/note_trainer_controller.dart';
import 'trainer_palette.dart';

class ShakeFeedback extends StatefulWidget {
  const ShakeFeedback({
    super.key,
    required this.tick,
    required this.text,
    required this.tone,
  });

  final int tick;
  final String text;
  final FeedbackTone tone;

  @override
  State<ShakeFeedback> createState() => _ShakeFeedbackState();
}

class _ShakeFeedbackState extends State<ShakeFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(ShakeFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tick != oldWidget.tick && widget.tone == FeedbackTone.wrong) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();
    final color = switch (widget.tone) {
      FeedbackTone.correct => TrainerPalette.green,
      FeedbackTone.wrong => TrainerPalette.red,
      FeedbackTone.info => const Color(0xFF3A3A3C),
    };
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final dx = math.sin(_shake.value * math.pi * 6) * 7 * (1 - _shake.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Container(
        key: const Key('trainer-feedback'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          widget.text,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}
