import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../curriculum/data/curriculum_asset_source.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import '../../curriculum/models/practice_set.dart';
import '../progress/progress_rules.dart';

class PracticeMapScreen extends StatelessWidget {
  const PracticeMapScreen({super.key, this.catalog, this.isMastered});

  final CurriculumCatalog? catalog;
  final bool Function(String competencyId)? isMastered;

  bool _mastered(String id) => isMastered?.call(id) ?? false;

  @override
  Widget build(BuildContext context) {
    if (catalog != null) return _MapBody(catalog: catalog!, isMastered: _mastered);
    return FutureBuilder<CurriculumCatalog>(
      future: const CurriculumAssetSource().load(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _MapBody(catalog: snapshot.data!, isMastered: _mastered);
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Не удалось загрузить практику'));
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _MapBody extends StatelessWidget {
  const _MapBody({required this.catalog, required this.isMastered});

  final CurriculumCatalog catalog;
  final bool Function(String competencyId) isMastered;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Практика', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 16),
            for (final set in catalog.practiceSets) _PracticeCard(set: set, catalog: catalog, isMastered: isMastered),
          ],
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({required this.set, required this.catalog, required this.isMastered});

  final PracticeSet set;
  final CurriculumCatalog catalog;
  final bool Function(String competencyId) isMastered;

  @override
  Widget build(BuildContext context) {
    final earlyIntervals = set.id == 'PR-03';
    final open = earlyIntervals ||
        (set.mvpStatus.isMvp && isTrainerOpen(set: set, catalog: catalog, isMastered: isMastered));
    final badge = !set.mvpStatus.isMvp
        ? 'Скоро'
        : earlyIntervals
            ? 'Стадии 1–3'
            : (open ? 'Открыто' : 'Закрыто');
    return Card(
      key: Key('practice-${set.id}'),
      child: ListTile(
        title: Text(set.title),
        subtitle: Text(badge),
        enabled: open,
        onTap: open ? () {} : null,
      ),
    );
  }
}
