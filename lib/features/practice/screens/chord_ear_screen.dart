import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../audio/audio_sequence.dart';
import '../audio/practice_audio_player.dart';
import '../trainers/triad_formulas.dart';

/// Стадия 1 PR-06. Вид аккорда считается по звукам, а не по подписи кнопки.
class ChordEarScreen extends StatefulWidget {
  const ChordEarScreen({super.key, required this.pitches, required this.player, required this.onAnswered});

  final List<int> pitches;
  final PracticeAudioPlayer player;
  final ValueChanged<bool> onAnswered;

  @override
  State<ChordEarScreen> createState() => _ChordEarScreenState();
}

class _ChordEarScreenState extends State<ChordEarScreen> {
  String? _feedback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.player.play(AudioSequence([ChordEvent(widget.pitches)]));
    });
  }

  void _choose(String name) {
    if (_feedback != null) return;
    final correct = TriadFormulas.classify(widget.pitches) == name;
    setState(() => _feedback = correct ? 'Верно' : 'Пока не то');
    widget.onAnswered(correct);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Большое или малое')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(onPressed: () => _choose('major'), child: const Text('большое')),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => _choose('minor'), child: const Text('малое')),
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
