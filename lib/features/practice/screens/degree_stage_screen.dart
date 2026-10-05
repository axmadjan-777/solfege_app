import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../audio/practice_audio_player.dart';
import '../trainers/degree_dictation.dart';
import '../widgets/sound_replay_button.dart';

/// Стадия 1 PR-01: каденция, затем «вернулось домой» или «висит в воздухе».
class DegreeStageScreen extends StatefulWidget {
  const DegreeStageScreen({
    super.key,
    required this.tonicMidi,
    required this.noteMidi,
    required this.player,
    required this.onAnswered,
    this.feedbackCorrect = 'Верно: фраза закончилась на тонике.',
    this.feedbackError = 'Послушай, вернулся ли звук домой.',
  });

  final int tonicMidi;
  final int noteMidi;
  final PracticeAudioPlayer player;
  final ValueChanged<bool> onAnswered;
  final String feedbackCorrect;
  final String feedbackError;

  @override
  State<DegreeStageScreen> createState() => _DegreeStageScreenState();
}

class _DegreeStageScreenState extends State<DegreeStageScreen> {
  String? _feedback;
  var _replays = SoundReplayButton.freeReplays;

  void _playStimulus() {
    widget.player.play(
      DegreeDictation.prompt(
        tonicMidi: widget.tonicMidi,
        noteMidi: widget.noteMidi,
      ),
    );
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

  void _choose(bool home) {
    if (_feedback != null) return;
    final correct =
        home == DegreeDictation.arrivedHome(widget.tonicMidi, widget.noteMidi);
    setState(() =>
        _feedback = correct ? widget.feedbackCorrect : widget.feedbackError);
    widget.onAnswered(correct);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ступеневый диктант')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoundReplayButton(remaining: _replays, onPressed: _replay),
            const SizedBox(height: 12),
            const Text('Ноты скрыты до ответа'),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: () => _choose(true),
                child: const Text('вернулось домой')),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: () => _choose(false),
                child: const Text('висит в воздухе')),
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
