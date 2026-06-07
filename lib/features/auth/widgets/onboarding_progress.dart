import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Шаг $currentStep из $totalSteps',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: currentStep / totalSteps,
            minHeight: 4,
            backgroundColor: AppColors.surfaceVariant,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
