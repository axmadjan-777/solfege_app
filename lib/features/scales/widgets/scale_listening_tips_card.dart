import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ScaleListeningTipsCard extends StatelessWidget {
  const ScaleListeningTipsCard({super.key, required this.tips});

  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hearing_rounded,
                size: 22,
                color: AppColors.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 10),
              Text(
                'Что важно услышать',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < tips.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tips[i],
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                  ),
                ),
              ],
            ),
            if (i < tips.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
