import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../trainers/note_reading.dart';

/// Стадия 1 PR-08: опоры и соседи C4–G4.
class NoteReadingScreen extends StatelessWidget {
  const NoteReadingScreen({super.key, required this.midi, required this.unlocked, required this.onAnswer});

  final int midi;
  final bool unlocked;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final options = ['до', 'ре', 'ми', 'фа', 'соль'];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Опоры и соседи (C4–G4)')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: unlocked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Позиция ${NoteReading.trebleY(midi).toStringAsFixed(0)}'),
                  const SizedBox(height: 12),
                  for (final option in options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilledButton(onPressed: () => onAnswer(option), child: Text(option)),
                    ),
                ],
              )
            : const Text('Закрыто: сначала освой чтение опор'),
      ),
    );
  }
}
