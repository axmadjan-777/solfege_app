import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../audio/practice_audio_player.dart';
import '../trainers/scale_ear.dart';
import '../widgets/sound_replay_button.dart';

/// Стадия 2 PR-05: мажор или минор после пяти звуков и тонического трезвучия.
class ScaleEarScreen extends StatefulWidget {
  const ScaleEarScreen({
    super.key,
    required this.major,
    required this.player,
    required this.onAnswered,
  });

  final bool major;
  final PracticeAudioPlayer player;
  final ValueChanged<bool> onAnswered;

  @override
  State<ScaleEarScreen> createState() => _ScaleEarScreenState();
}

class _ScaleEarScreenState extends State<ScaleEarScreen> {
  String? _feedback;
  var _replays = SoundReplayButton.freeReplays;

  void _playStimulus() {
    widget.player.play(scaleHearingContext(major: widget.major));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playStimulus());
  }

  void _replay() {
    if (_replays <= 0) return;
    setState(() => _replays -= 1);
    _playStimulus();
  }

  void _choose(bool major) {
    if (_feedback != null) return;
    final correct = major == widget.major;
    setState(() => _feedback = correct ? 'Верно' : 'Пока не то');
    widget.onAnswered(correct);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Мажор или минор')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoundReplayButton(remaining: _replays, onPressed: _replay),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: () => _choose(true), child: const Text('мажор')),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: () => _choose(false), child: const Text('минор')),
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
