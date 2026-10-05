import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../trainers/daily_mix.dart';

class DailyMixScreen extends StatelessWidget {
  const DailyMixScreen({super.key, required this.plan});

  final DailyMixPlan plan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ежедневный микс')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Заданий: ${plan.items.length}'),
            Text('Должное: ${plan.countOf(MixBucket.due)}'),
            Text('Недавнее: ${plan.countOf(MixBucket.recent)}'),
            Text('Лёгкое: ${plan.countOf(MixBucket.easy)}'),
          ],
        ),
      ),
    );
  }
}
