import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../audio/practice_audio_player.dart';
import '../trainers/minor_degree_dictation.dart';
import '../widgets/sound_replay_button.dart';

/// Стадия 1 PR-02: тоника ля минора или незавершённый звук.
class MinorDegreeScreen extends StatefulWidget {
  const MinorDegreeScreen({
    super.key,
    required this.tonicMidi,
    required this.noteMidi,
    required this.player,
    required this.onAnswered,
  });

  final int tonicMidi;
  final int noteMidi;
  final PracticeAudioPlayer player;
  final ValueChanged<bool> onAnswered;

  @override
  State<MinorDegreeScreen> createState() => _MinorDegreeScreenState();
}

class _MinorDegreeScreenState extends State<MinorDegreeScreen> {
  String? _feedback;
  var _replays = SoundReplayButton.freeReplays;

  void _playStimulus() {
    widget.player.play(
      MinorDegreeDictation.prompt(noteMidi: widget.noteMidi),
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
    final correct = home ==
        MinorDegreeDictation.arrivedHome(widget.tonicMidi, widget.noteMidi);
    setState(() => _feedback = correct ? 'Верно' : 'Пока не то');
    widget.onAnswered(correct);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Тоника минора')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoundReplayButton(remaining: _replays, onPressed: _replay),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: () => _choose(true),
                child: const Text('вернулось домой')),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: () => _choose(false),
                child: const Text('висит в воздухе')),
            if (_feedback != null) Text(_feedback!),
          ],
        ),
      ),
    );
  }
}
