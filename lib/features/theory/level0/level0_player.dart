import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../interaction/templates/level01_templates.dart';
import '../../interaction/templates/tap_template.dart';
import '../../practice/progress/attempt.dart';
import 'level0_plan.dart';

class Level0Result {
  const Level0Result({
    required this.lessonId,
    required this.correct,
    required this.total,
    this.trainPracticeSetIds = const [],
  });

  final String lessonId;
  final int correct;
  final int total;
  final List<String> trainPracticeSetIds;

  CompetencyStatus get status => statusAfterLesson();
}

class Level0Player extends StatefulWidget {
  const Level0Player({super.key, required this.plan, required this.onFinished});

  final Level0Plan plan;
  final ValueChanged<Level0Result> onFinished;

  @override
  State<Level0Player> createState() => _Level0PlayerState();
}

class _Level0PlayerState extends State<Level0Player> {
  var _index = 0;
  var _correct = 0;
  var _answered = 0;
  String? _feedback;
  var _summary = false;

  Level0Step? get _step => _summary ? null : widget.plan.steps[_index];

  void _mark(bool correct, String feedback) {
    if (_feedback != null) return;
    setState(() {
      _feedback = feedback;
      _answered += 1;
      if (correct) _correct += 1;
    });
  }

  void _advance() {
    if (_index + 1 >= widget.plan.steps.length) {
      setState(() => _summary = true);
      return;
    }
    setState(() {
      _index += 1;
      _feedback = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.plan.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _summary ? _summaryView(context) : _stepView(context),
        ),
      ),
    );
  }

  Widget _stepView(BuildContext context) {
    final step = _step!;
    if (step.isExplanation) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.body),
          const SizedBox(height: 16),
          FilledButton(onPressed: _advance, child: const Text('Дальше')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (step.templateId == 'T09')
          TapPulseTemplate(
            prompt: step.body,
            tapsRequired: step.tapsRequired,
            onResult: (result) => _mark(result.correct, step.feedbackCorrect),
          )
        else if (step.templateId == 'T03')
          MultiChoiceTemplate(
            prompt: step.body,
            options: step.options,
            correctIndexes: step.correctIndexes,
            onResult: (result) => _mark(result.correct, result.correct ? step.feedbackCorrect : step.feedbackError),
          )
        else ...[
          Text(step.body),
          const SizedBox(height: 12),
          for (var i = 0; i < step.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton(
                onPressed: _feedback == null
                    ? () => _mark(i == step.correctIndex, i == step.correctIndex ? step.feedbackCorrect : step.feedbackError)
                    : null,
                child: Text(step.options[i]),
              ),
            ),
        ],
        if (_feedback != null) ...[
          const SizedBox(height: 12),
          Text(_feedback!),
          const SizedBox(height: 12),
          FilledButton(onPressed: _advance, child: const Text('Дальше')),
        ],
      ],
    );
  }

  Widget _summaryView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Итог', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Верно $_correct из $_answered'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            widget.onFinished(
              Level0Result(
                lessonId: widget.plan.lessonId,
                correct: _correct,
                total: _answered,
                trainPracticeSetIds: widget.plan.trainPracticeSetIds,
              ),
            );
          },
          child: const Text('Тренировать'),
        ),
      ],
    );
  }
}
