import 'package:flutter/material.dart';

import '../models/key_signature_category.dart';

class KeySignatureFilterChips extends StatelessWidget {
  const KeySignatureFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final KeySignatureFilter selected;
  final ValueChanged<KeySignatureFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: KeySignatureFilter.values.map((filter) {
        final isSelected = selected == filter;
        return FilterChip(
          label: Text(
            filter.labelRu,
            softWrap: false,
          ),
          selected: isSelected,
          onSelected: (_) => onSelected(filter),
          labelStyle: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.7,
                    ),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        );
      }).toList(),
    );
  }
}
