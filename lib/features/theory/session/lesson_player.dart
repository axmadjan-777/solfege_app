import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../interaction/templates/single_choice_template.dart';
import '../../practice/progress/attempt.dart';
import 'lesson_script.dart';

/// Итог урока. `mastered` здесь не ставится: потолок сессии ниже.
class LessonAttempt {
  const LessonAttempt({required this.correct, required this.total});

  final int correct;
  final int total;

  CompetencyStatus get status => CompetencyStatus.provisionallyPassed;
}

class LessonPlayer extends StatefulWidget {
  const LessonPlayer({super.key, required this.script, required this.onFinished});

  final LessonScript script;
  final ValueChanged<LessonAttempt> onFinished;

  @override
  State<LessonPlayer> createState() => _LessonPlayerState();
}

class _LessonPlayerState extends State<LessonPlayer> {
  var _index = 0;
  var _correct = 0;
  var _answered = 0;
  String? _feedback;
  var _summary = false;
  var _recorded = false;

  LessonStep? get _step => _summary ? null : widget.script.steps[_index];

  void _select(int index) {
    final step = _step;
    if (step == null || _feedback != null) return;
    final correct = index == step.correctIndex;
    setState(() {
      _feedback = correct ? step.feedbackCorrect : step.feedbackError;
      _answered += 1;
      if (correct) _correct += 1;
    });
  }

  void _advance() {
    if (_index + 1 >= widget.script.steps.length) {
      setState(() => _summary = true);
      return;
    }
    setState(() {
      _index += 1;
      _feedback = null;
    });
  }

  void _train() {
    if (_recorded) return;
    _recorded = true;
    widget.onFinished(LessonAttempt(correct: _correct, total: _answered));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.script.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _summary ? _buildSummary(context) : _buildStep(context),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    final step = _step!;
    if (!step.isChoice) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Объяснение', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(step.body),
          const SizedBox(height: 8),
          Text('${widget.script.explanationSeconds} с'),
          const Spacer(),
          FilledButton(onPressed: _advance, child: const Text('Дальше')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChoiceTemplate(
          templateId: step.templateId,
          prompt: step.body,
          options: step.options,
          showHint: step.allowsHint && _feedback == null,
          onHint: () {},
          onSelect: _select,
        ),
        if (_feedback != null) ...[
          Text(_feedback!),
          const SizedBox(height: 12),
          FilledButton(onPressed: _advance, child: const Text('Дальше')),
        ],
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Итог', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Верно $_correct из $_answered'),
        const Spacer(),
        FilledButton(onPressed: _train, child: Text(widget.script.trainLabel)),
      ],
    );
  }
}
