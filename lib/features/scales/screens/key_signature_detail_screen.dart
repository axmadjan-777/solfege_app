import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/key_signature_group.dart';
import '../models/scale.dart';
import '../widgets/scale_card.dart';
import 'scale_detail_screen.dart';

class KeySignatureDetailScreen extends StatelessWidget {
  const KeySignatureDetailScreen({
    super.key,
    required this.group,
  });

  final KeySignatureGroup group;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(group.title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            _InfoCard(group: group),
            const SizedBox(height: 28),
            _ScaleSection(
              title: 'Мажорные варианты',
              scales: group.majorScales,
            ),
            const SizedBox(height: 28),
            _ScaleSection(
              title: 'Минорные варианты',
              scales: group.minorScales,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.group});

  final KeySignatureGroup group;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.category.labelRu,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Ключевые знаки: ${group.signCountLabel}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (group.signLabels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                group.signLabels.join(', '),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScaleSection extends StatelessWidget {
  const _ScaleSection({
    required this.title,
    required this.scales,
  });

  final String title;
  final List<Scale> scales;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ...scales.map(
          (scale) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ScaleCard(
              scale: scale,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ScaleDetailScreen(scale: scale),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
