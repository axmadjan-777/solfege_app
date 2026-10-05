import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../curriculum/data/curriculum_asset_source.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import '../level0/level0_plan.dart';
import '../level0/level0_player.dart';
import 'theory_level_screen.dart';

class TheoryHomeScreen extends StatelessWidget {
  const TheoryHomeScreen({super.key, this.catalog, this.isMastered});

  final CurriculumCatalog? catalog;
  final bool Function(String competencyId)? isMastered;

  bool _mastered(String id) => isMastered?.call(id) ?? false;

  @override
  Widget build(BuildContext context) {
    if (catalog != null) {
      return _Home(catalog: catalog!, isMastered: _mastered);
    }
    return FutureBuilder<CurriculumCatalog>(
      future: const CurriculumAssetSource().load(),
      builder: (context, snapshot) {
        if (snapshot.hasData) return _Home(catalog: snapshot.data!, isMastered: _mastered);
        if (snapshot.hasError) return const Center(child: Text('Не удалось загрузить теорию'));
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({required this.catalog, required this.isMastered});

  final CurriculumCatalog catalog;
  final bool Function(String competencyId) isMastered;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: TheoryLevelScreen(
          catalog: catalog,
          isMastered: isMastered,
          onOpen: (lesson) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Level0Player(
                  plan: Level0Plan.fromLesson(lesson),
                  onFinished: (_) {},
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
