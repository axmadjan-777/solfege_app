import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../audio/practice_audio_player.dart';
import '../trainers/scale_keys.dart';

/// Стадия 3: собрать порядок диезов или бемолей.
class SharpOrderScreen extends StatefulWidget {
  const SharpOrderScreen({
    super.key,
    required this.pool,
    required this.expected,
    required this.onAnswered,
    this.correctFeedback = sharpOrderFeedback,
    this.firstError = sharpOrderFirstError,
    this.repeatError = sharpOrderRepeatError,
  });

  final List<String> pool;
  final List<String> expected;
  final ValueChanged<bool> onAnswered;
  final String correctFeedback;
  final String firstError;
  final String repeatError;

  @override
  State<SharpOrderScreen> createState() => _SharpOrderScreenState();
}

class _SharpOrderScreenState extends State<SharpOrderScreen> {
  final _placed = <String>[];
  String? _feedback;

  void _add(String note) {
    if (_feedback != null || _placed.contains(note)) return;
    setState(() => _placed.add(note));
    if (_placed.length < widget.expected.length) return;
    final correct = sameOrder(_placed, widget.expected);
    final feedback = correct
        ? widget.correctFeedback
        : gSharpBeforeCSharp(_placed)
            ? widget.repeatError
            : widget.firstError;
    setState(() => _feedback = feedback);
    widget.onAnswered(correct);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Порядок знаков')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Поставь знаки в порядке'),
            const SizedBox(height: 8),
            Text(_placed.join(' ')),
            const SizedBox(height: 12),
            for (final note in widget.pool)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(onPressed: () => _add(note), child: Text(note)),
              ),
            if (_feedback != null) Text(_feedback!),
          ],
        ),
      ),
    );
  }
}

/// Стадия 4: собрать вид минора шагами. После ответа звучит гамма вверх и вниз.
class MinorBuilderScreen extends StatefulWidget {
  const MinorBuilderScreen({
    super.key,
    required this.form,
    required this.tonic,
    required this.player,
    required this.onAnswered,
    this.correctFeedback = harmonicFeedback,
    this.firstError = harmonicFirstError,
    this.repeatError = harmonicRepeatError,
  });

  final MinorForm form;
  final int tonic;
  final PracticeAudioPlayer player;
  final ValueChanged<bool> onAnswered;
  final String correctFeedback;
  final String firstError;
  final String repeatError;

  @override
  State<MinorBuilderScreen> createState() => _MinorBuilderScreenState();
}

class _MinorBuilderScreenState extends State<MinorBuilderScreen> {
  final _steps = <int>[];
  String? _feedback;

  void _add(String name) {
    if (_feedback != null || _steps.length >= 7) return;
    setState(() => _steps.add(stepSize(name)));
    if (_steps.length < 7) return;
    final correct = matchesMinor(widget.form, _steps);
    final feedback = correct
        ? widget.correctFeedback
        : widget.form == MinorForm.harmonic && sixthAndSeventhRaised(_steps)
            ? widget.repeatError
            : widget.firstError;
    setState(() => _feedback = feedback);
    widget.player.play(minorUpAndDown(widget.tonic, widget.form));
    widget.onAnswered(correct);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.form) {
      MinorForm.natural => 'Натуральный минор',
      MinorForm.harmonic => 'Гармонический минор',
      MinorForm.melodic => 'Мелодический минор',
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_steps.map(stepName).join(' ')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => _add('тон'), child: const Text('тон')),
            OutlinedButton(onPressed: () => _add('полутон'), child: const Text('полутон')),
            OutlinedButton(onPressed: () => _add('полтора'), child: const Text('полтора')),
            if (_feedback != null) Text(_feedback!),
          ],
        ),
      ),
    );
  }
}

/// Стадия 5: параллельный минор, не одноимённый.
class RelativeKeyScreen extends StatefulWidget {
  const RelativeKeyScreen({
    super.key,
    required this.major,
    required this.choices,
    required this.onAnswered,
    this.correctFeedback = relativeFeedback,
    this.firstError = relativeFirstError,
    this.repeatError = relativeRepeatError,
  });

  final String major;
  final List<String> choices;
  final ValueChanged<bool> onAnswered;
  final String correctFeedback;
  final String firstError;
  final String repeatError;

  @override
  State<RelativeKeyScreen> createState() => _RelativeKeyScreenState();
}

class _RelativeKeyScreenState extends State<RelativeKeyScreen> {
  String? _feedback;

  void _choose(String minor) {
    if (_feedback != null) return;
    final correct = isRelativeMinor(widget.major, minor);
    final feedback = correct
        ? widget.correctFeedback
        : isParallelMinor(widget.major, minor)
            ? widget.repeatError
            : widget.firstError;
    setState(() => _feedback = feedback);
    widget.onAnswered(correct);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Параллельная тональность')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Параллельный минор к ${widget.major} мажор'),
            const SizedBox(height: 12),
            for (final minor in widget.choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton(
                  onPressed: () => _choose(minor),
                  child: Text('$minor минор'),
                ),
              ),
            if (_feedback != null) Text(_feedback!),
          ],
        ),
      ),
    );
  }
}
