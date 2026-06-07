import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ScaleDegreeChip extends StatelessWidget {
  const ScaleDegreeChip({
    super.key,
    required this.degree,
    required this.note,
    this.isHighlighted = false,
  });

  final String degree;
  final String note;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlighted
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.divider,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              degree,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color:
                        isHighlighted ? AppColors.primary : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
