import 'package:flutter/material.dart';

import 'level01_templates.dart';

/// Мажор: тон, тон, полутон, тон, тон, тон, полутон.
const majorScaleSteps = ['тон', 'тон', 'полутон', 'тон', 'тон', 'тон', 'полутон'];

bool isMajorScale(List<String> steps) => steps.join('|') == majorScaleSteps.join('|');

/// T07 — конструктор гаммы из шагов тон и полутон.
class ScaleBuilderTemplate extends StatefulWidget {
  const ScaleBuilderTemplate({super.key, required this.onResult});

  final ValueChanged<TemplateResult> onResult;

  @override
  State<ScaleBuilderTemplate> createState() => _ScaleBuilderTemplateState();
}

class _ScaleBuilderTemplateState extends State<ScaleBuilderTemplate> {
  final _steps = <String>[];
  TemplateResult? _result;

  void _add(String step) {
    if (_result != null || _steps.length >= majorScaleSteps.length) return;
    TemplateResult? result;
    setState(() {
      _steps.add(step);
      if (_steps.length < majorScaleSteps.length) return;
      final correct = isMajorScale(_steps);
      result = TemplateResult(correct: correct, credit: correct ? 1 : 0, feedback: correct ? 'Верно' : 'Пока не то');
      _result = result;
    });
    if (result != null) widget.onResult(result!);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Собери мажор'),
        Text(_steps.join(' ')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => _add('тон'), child: const Text('тон')),
        OutlinedButton(onPressed: () => _add('полутон'), child: const Text('полутон')),
        if (_result != null) Text(_result!.feedback),
      ],
    );
  }
}
