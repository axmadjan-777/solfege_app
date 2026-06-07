import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/scale_direction.dart';

class ScalePlayButton extends StatelessWidget {
  const ScalePlayButton({
    super.key,
    required this.direction,
    required this.onPressed,
    this.isLoading = false,
  });

  final ScaleDirection direction;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final icon = switch (direction) {
      ScaleDirection.ascending => Icons.arrow_upward_rounded,
      ScaleDirection.descending => Icons.arrow_downward_rounded,
      ScaleDirection.upDown => Icons.swap_vert_rounded,
    };

    final filled = direction == ScaleDirection.ascending;

    return SizedBox(
      width: double.infinity,
      child: filled
          ? ElevatedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: _buildIcon(icon, filled: true),
              label: Text(
                direction.buttonLabel,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            )
          : OutlinedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: _buildIcon(icon, filled: false),
              label: Text(
                direction.buttonLabel,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ),
    );
  }

  Widget _buildIcon(IconData icon, {required bool filled}) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: filled ? AppColors.surface : AppColors.primary,
        ),
      );
    }
    return Icon(icon, size: 20);
  }
}
