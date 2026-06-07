import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ScaleNotesRow extends StatelessWidget {
  const ScaleNotesRow({
    super.key,
    required this.notes,
    this.compact = false,
  });

  final List<String> notes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Text(
        notes.join(' · '),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < notes.length; i++) ...[
          _NotePill(note: notes[i], large: true),
          if (i < notes.length - 1)
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
        ],
      ],
    );
  }
}

class _NotePill extends StatelessWidget {
  const _NotePill({
    required this.note,
    this.large = false,
  });

  final String note;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 10,
        vertical: large ? 12 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        note,
        style: (large
                ? Theme.of(context).textTheme.titleLarge
                : Theme.of(context).textTheme.titleMedium)
            ?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
