import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../scales/utils/solfege_notes.dart';
import '../audio/audio_sequence.dart';
import '../audio/practice_audio_player.dart';
import '../trainers/sight_reading.dart';
import '../widgets/sound_replay_button.dart';

/// Стадия 1 PR-13: четыре ноты, только высота.
class SightReadingScreen extends StatefulWidget {
  const SightReadingScreen({
    super.key,
    required this.phrase,
    required this.player,
    required this.onFinished,
  });

  final SightPhrase phrase;
  final PracticeAudioPlayer player;
  final ValueChanged<bool> onFinished;

  @override
  State<SightReadingScreen> createState() => _SightReadingScreenState();
}

class _SightReadingScreenState extends State<SightReadingScreen> {
  var _index = 0;
  var _wrong = false;
  var _replays = SoundReplayButton.freeReplays;

  void _playStimulus() {
    widget.player.play(
      AudioSequence([
        for (final degree in widget.phrase.degrees)
          NoteEvent(60 + SightPhrase.scale[degree - 1]),
      ]),
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

  void _tap(int degree) {
    if (_wrong || _index >= widget.phrase.degrees.length) return;
    if (degree != widget.phrase.degrees[_index]) {
      setState(() => _wrong = true);
      widget.onFinished(false);
      return;
    }
    _index += 1;
    if (_index == widget.phrase.degrees.length) widget.onFinished(true);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('4 такта, только высота')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoundReplayButton(remaining: _replays, onPressed: _replay),
            const SizedBox(height: 12),
            Text('Сыграно $_index из ${widget.phrase.degrees.length}'),
            const SizedBox(height: 12),
            for (final name in SolfegeNotes.naturalNames)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton(
                  onPressed: () =>
                      _tap(SolfegeNotes.naturalNames.indexOf(name) + 1),
                  child: Text(name),
                ),
              ),
            if (_wrong) const Text('Пока не то'),
          ],
        ),
      ),
    );
  }
}
