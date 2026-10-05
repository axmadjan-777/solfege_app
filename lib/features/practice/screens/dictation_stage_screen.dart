import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../interaction/templates/level01_templates.dart';
import '../../interaction/templates/rhythm_grid_template.dart';
import '../trainers/rhythm_dictation.dart';

/// Стадия 1 PR-10: выбрать запись, затем собрать один такт.
class DictationStageScreen extends StatefulWidget {
  const DictationStageScreen({super.key, required this.onFinished});

  final ValueChanged<bool> onFinished;

  @override
  State<DictationStageScreen> createState() => _DictationStageScreenState();
}

class _DictationStageScreenState extends State<DictationStageScreen> {
  var _chosen = false;
  var _built = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ритмический диктант')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _chosen ? _grid() : _choice(),
      ),
    );
  }

  Widget _choice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Повторов: 3'),
        const SizedBox(height: 12),
        for (final label in const ['запись 1', 'запись 2', 'запись 3'])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton(
              onPressed: () => setState(() => _chosen = label == 'запись 2'),
              child: Text(label),
            ),
          ),
      ],
    );
  }

  Widget _grid() {
    return RhythmGridTemplate(
      prompt: 'Собери такт 4/4',
      beats: 4,
      palette: const ['четверть'],
      expected: const ['четверть', 'четверть', 'четверть', 'четверть'],
      onResult: (TemplateResult result) {
        if (_built) return;
        _built = true;
        widget.onFinished(result.correct && RhythmDictation.barFits(const ['четверть', 'четверть', 'четверть', 'четверть'], beatsInBar: 4));
      },
    );
  }
}
