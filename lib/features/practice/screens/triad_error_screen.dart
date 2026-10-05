import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../trainers/triad_build.dart';
import '../trainers/triad_formulas.dart';

/// Стадия 4 PR-07: в аккорде лишний полутон, нужно вернуть формулу 0–4–7.
class TriadErrorScreen extends StatelessWidget {
  const TriadErrorScreen({super.key, required this.pitches, required this.onAnswered});

  final List<int> pitches;
  final ValueChanged<bool> onAnswered;

  @override
  Widget build(BuildContext context) {
    final fixes = [
      correctThird(pitches, TriadFormulas.major),
      correctThird(pitches, TriadFormulas.minor),
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Найди и исправь ошибку')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Сейчас звуки $pitches'),
            const SizedBox(height: 12),
            for (final fix in fixes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton(
                  onPressed: () => onAnswered(TriadFormulas.classify(fix) == 'major'),
                  child: Text(fix.join('–')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
