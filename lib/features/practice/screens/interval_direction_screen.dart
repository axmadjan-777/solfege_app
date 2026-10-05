import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../scales/utils/solfege_notes.dart';
import '../trainers/interval_direction.dart';

/// Стадии 3–4: выбрать звук интервала вверх или вниз. Верный MIDI считается по формуле.
class IntervalDirectionScreen extends StatelessWidget {
  const IntervalDirectionScreen({
    super.key,
    required this.startMidi,
    required this.label,
    required this.upward,
    required this.choices,
    required this.onAnswered,
  });

  final int startMidi;
  final String label;
  final bool upward;
  final List<int> choices;
  final ValueChanged<bool> onAnswered;

  int get target => upward ? noteAbove(startMidi, label) : noteBelow(startMidi, label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(upward ? 'Интервал вверх' : 'Интервал вниз')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(upward ? 'От $startMidi вверх: $label' : 'От $startMidi вниз: $label'),
            const SizedBox(height: 12),
            for (final midi in choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton(
                  onPressed: () => onAnswered(midi == target),
                  child: Text(SolfegeNotes.fromMidi(midi, useFlats: false)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
