import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/musician_level.dart';

class MusicianLevelCard extends StatelessWidget {
  const MusicianLevelCard({
    super.key,
    required this.level,
    required this.isSelected,
    required this.onTap,
  });

  final MusicianLevel level;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.divider,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.labelRu,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      level.descriptionRu,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
