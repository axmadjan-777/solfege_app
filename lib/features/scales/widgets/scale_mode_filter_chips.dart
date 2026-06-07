import 'package:flutter/material.dart';

import '../models/scale_mode_filter.dart';

class ScaleModeFilterChips extends StatelessWidget {
  const ScaleModeFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ScaleModeFilter selected;
  final ValueChanged<ScaleModeFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final filter in ScaleModeFilter.values)
          FilterChip(
            label: Text(filter.label),
            selected: selected == filter,
            onSelected: (_) => onSelected(filter),
          ),
      ],
    );
  }
}
