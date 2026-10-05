import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../progress/attempt.dart';
import '../trainers/assessment.dart';

class DiagnosticScreen extends StatelessWidget {
  const DiagnosticScreen({super.key, required this.rules, required this.onFinished});

  final AssessmentRules rules;
  final ValueChanged<CompetencyStatus> onFinished;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Диагностика')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final axis in rules.diagnosticAxes) Text(axis),
            const Spacer(),
            FilledButton(
              onPressed: () => onFinished(rules.diagnosticStatus()),
              child: const Text('Завершить'),
            ),
          ],
        ),
      ),
    );
  }
}
