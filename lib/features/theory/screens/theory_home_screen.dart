import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../session/lesson_player.dart';
import '../session/lesson_script.dart';

class TheoryHomeScreen extends StatelessWidget {
  const TheoryHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Теория', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 12),
              Text(
                'Урок на 5–10 минут',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LessonPlayer(script: LessonScript.sampleT01(), onFinished: (_) {}),
                    ),
                  );
                },
                child: const Text('Открыть урок'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
