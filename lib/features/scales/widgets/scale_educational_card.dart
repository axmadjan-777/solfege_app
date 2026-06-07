import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/scale.dart';
import '../models/scale_mode.dart';

class ScaleEducationalCard extends StatelessWidget {
  const ScaleEducationalCard({super.key, required this.scale});

  final Scale scale;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Что важно в этом ладе',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              scale.mode.educationalHintRu,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (scale.mode == ScaleMode.melodicMinor) ...[
              const SizedBox(height: 12),
              Text(
                'Вниз: ${scale.descendingNotes?.join(' · ') ?? 'натуральный минор'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
