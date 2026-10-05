import 'package:flutter/material.dart';

import 'level01_templates.dart';

/// T12 — найти ошибку и назвать верный вариант.
class FindErrorTemplate extends StatelessWidget {
  const FindErrorTemplate({
    super.key,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.onResult,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
  final ValueChanged<TemplateResult> onResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(prompt),
        const SizedBox(height: 12),
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton(
              onPressed: () {
                final correct = i == correctIndex;
                onResult(
                  TemplateResult(correct: correct, credit: correct ? 1 : 0, feedback: correct ? 'Верно' : 'Пока не то'),
                );
              },
              child: Text(options[i]),
            ),
          ),
      ],
    );
  }
}
