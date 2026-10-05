import 'package:flutter/material.dart';

import '../../scales/utils/solfege_notes.dart';
import '../../scales/utils/treble_staff_layout.dart';

/// T05 — нота на стане. Позиция считается существующей геометрией скрипичного ключа.
class StaffNoteTemplate extends StatelessWidget {
  const StaffNoteTemplate({super.key, required this.midi, required this.onAnswer});

  final int midi;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final name = SolfegeNotes.fromMidi(midi, useFlats: false);
    final y = TrebleStaffLayout.yForMidi(midi, topPadding: 8, lineGap: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Нота на стане, позиция ${y.toStringAsFixed(0)}'),
        Text(name, key: Key('staff-name-$midi')),
        const SizedBox(height: 12),
        for (final option in const ['до', 'ре', 'ми', 'фа', 'соль'])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton(onPressed: () => onAnswer(option), child: Text(option)),
          ),
      ],
    );
  }
}
