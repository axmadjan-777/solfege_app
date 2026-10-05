import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../audio/practice_audio_player.dart';
import '../trainers/interval_ear.dart';

/// Стадия 2 PR-03: малая или большая терция. Уроки L05 не требуются.
class IntervalStageScreen extends StatefulWidget {
  const IntervalStageScreen({
    super.key,
    required this.task,
    required this.onAnswered,
    this.player,
  });

  final IntervalTask task;
  final ValueChanged<bool> onAnswered;
  final PracticeAudioPlayer? player;

  @override
  State<IntervalStageScreen> createState() => _IntervalStageScreenState();
}

class _IntervalStageScreenState extends State<IntervalStageScreen> {
  String? _feedback;

  Future<void> _choose(String label) async {
    if (_feedback != null) return;
    final correct = label == widget.task.label;
    if (!correct && widget.player != null) {
      final chosen = label == 'м3' ? 3 : 4;
      await widget.player!.play(
        intervalComparison(
          bassMidi: widget.task.bassMidi,
          correctSemitones: widget.task.semitones,
          chosenSemitones: chosen,
        ),
      );
    }
    setState(() => _feedback = correct ? 'Верно' : 'Пока не то');
    widget.onAnswered(correct);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Малая и большая терция')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Нижний звук ${widget.task.bassMidi}, интервал ${widget.task.semitones} полутона'),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => _choose('м3'), child: const Text('м3')),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => _choose('б3'), child: const Text('б3')),
            if (_feedback != null) ...[
              const SizedBox(height: 16),
              Text(_feedback!),
            ],
          ],
        ),
      ),
    );
  }
}
