import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../audio/practice_audio_player.dart';
import '../trainers/interval_ear.dart';

/// Стадии 4–8. Имя интервала считается по числу полутонов, не по подписи кнопки.
class IntervalChoiceScreen extends StatefulWidget {
  const IntervalChoiceScreen({
    super.key,
    required this.bassMidi,
    required this.steps,
    required this.labels,
    required this.harmonic,
    required this.player,
    required this.onAnswered,
  });

  final int bassMidi;
  final int steps;
  final List<String> labels;
  final bool harmonic;
  final PracticeAudioPlayer player;
  final ValueChanged<bool> onAnswered;

  @override
  State<IntervalChoiceScreen> createState() => _IntervalChoiceScreenState();
}

class _IntervalChoiceScreenState extends State<IntervalChoiceScreen> {
  String? _feedback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.player.play(
        intervalPlayback(bassMidi: widget.bassMidi, steps: widget.steps, harmonic: widget.harmonic),
      );
    });
  }

  void _choose(String label) {
    if (_feedback != null) return;
    final sounded = IntervalEar.labelFor(widget.steps);
    final correct = label == sounded;
    if (!correct) {
      final chosen = IntervalEar.semitones[label];
      if (chosen != null) {
        widget.player.play(
          intervalComparison(bassMidi: widget.bassMidi, correctSemitones: widget.steps, chosenSemitones: chosen),
        );
      }
    }
    setState(() => _feedback = correct ? 'Верно' : 'Пока не то');
    widget.onAnswered(correct);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.harmonic ? 'Гармонический интервал' : 'Интервал')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final label in widget.labels)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton(onPressed: () => _choose(label), child: Text(label)),
            ),
          if (_feedback != null) Text(_feedback!),
        ],
      ),
    );
  }
}
