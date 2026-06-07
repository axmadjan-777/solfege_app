import 'package:flutter/material.dart';

import '../models/scale.dart';
import 'scale_degree_chip.dart';

class ScaleDegreesGrid extends StatelessWidget {
  const ScaleDegreesGrid({super.key, required this.scale});

  final Scale scale;

  @override
  Widget build(BuildContext context) {
    final highlighted = scale.mode.highlightedDegrees;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < Scale.degrees.length; i++)
          SizedBox(
            width: 72,
            child: ScaleDegreeChip(
              degree: Scale.degrees[i],
              note: scale.notes[i],
              isHighlighted: highlighted.contains(Scale.degrees[i]),
            ),
          ),
      ],
    );
  }
}
