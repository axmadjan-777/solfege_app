import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../audio/practice_audio_player.dart';
import '../trainers/rhythm_trainer.dart';

/// Стадия 1 PR-09: тап в пульс. Без замка сессия не стартует.
class RhythmStageScreen extends StatefulWidget {
  const RhythmStageScreen({
    super.key,
    required this.unlocked,
    required this.player,
    required this.onHit,
  });

  final bool unlocked;
  final PracticeAudioPlayer player;
  final ValueChanged<bool> onHit;

  @override
  State<RhythmStageScreen> createState() => _RhythmStageScreenState();
}

class _RhythmStageScreenState extends State<RhythmStageScreen> {
  String? _feedback;

  @override
  void initState() {
    super.initState();
    if (!widget.unlocked) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.player.play(metronomeClicks(bpm: 80));
    });
  }

  void _tap() {
    if (!widget.unlocked || _feedback != null) return;
    setState(() => _feedback = 'Верно');
    widget.onHit(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Пульс')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: widget.unlocked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Тапни вместе с кликом'),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _tap, child: const Text('Тап')),
                  if (_feedback != null) Text(_feedback!),
                ],
              )
            : const Text('Закрыто: сначала освой пульс'),
      ),
    );
  }
}
