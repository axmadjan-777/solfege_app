import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../scales/utils/solfege_notes.dart';

/// Стадия 2 PR-04: построить терцию и квинту от до.
class IntervalBuildScreen extends StatefulWidget {
  const IntervalBuildScreen({super.key, required this.onFinished});

  final ValueChanged<bool> onFinished;

  @override
  State<IntervalBuildScreen> createState() => _IntervalBuildScreenState();
}

class _IntervalBuildScreenState extends State<IntervalBuildScreen> {
  final _picked = <String>[];

  void _tap(String name) {
    if (_picked.length >= 2 || _picked.contains(name)) return;
    setState(() => _picked.add(name));
    if (_picked.length < 2) return;
    widget.onFinished(_picked[0] == 'ми' && _picked[1] == 'соль');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Терция и квинта')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('От до построй терцию, затем квинту'),
            const SizedBox(height: 12),
            for (final name in SolfegeNotes.naturalNames.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton(onPressed: () => _tap(name), child: Text(name)),
              ),
          ],
        ),
      ),
    );
  }
}
