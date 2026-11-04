import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../coach/coach_layer.dart';
import '../../curriculum/data/curriculum_asset_source.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import '../../curriculum/models/practice_set.dart';
import '../audio/practice_audio_player.dart';
import '../audio/synthetic_practice_audio_player.dart';
import '../progress/clock.dart';
import '../progress/progress_store.dart';
import '../progress/progress_rules.dart';
import '../trainers/assessment.dart';
import '../trainers/minor_degree_dictation.dart';
import 'diagnostic_screen.dart';
import 'practice_round_screen.dart';

class PracticeMapScreen extends StatelessWidget {
  const PracticeMapScreen({
    super.key,
    this.catalog,
    this.isMastered,
    this.player,
    this.progress,
    this.clock,
  });

  final CurriculumCatalog? catalog;
  final bool Function(String competencyId)? isMastered;
  final PracticeAudioPlayer? player;
  final ProgressStore? progress;
  final Clock? clock;

  bool _mastered(String id) => isMastered?.call(id) ?? false;

  @override
  Widget build(BuildContext context) {
    if (catalog != null) {
      return _MapBody(
          catalog: catalog!,
          isMastered: _mastered,
          player: player,
          progress: progress,
          clock: clock);
    }
    return FutureBuilder<CurriculumCatalog>(
      future: const CurriculumAssetSource().load(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _MapBody(
            catalog: snapshot.data!,
            isMastered: _mastered,
            player: player,
            progress: progress,
            clock: clock,
          );
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
  const _MapBody({
    required this.catalog,
    required this.isMastered,
    required this.player,
    required this.progress,
    required this.clock,
  });

  final CurriculumCatalog catalog;
  final bool Function(String competencyId) isMastered;
  final PracticeAudioPlayer? player;
  final ProgressStore? progress;
  final Clock? clock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            CoachTarget(
              id: 'practice-heading',
              child: Text('Практика',
                  style: Theme.of(context).textTheme.displaySmall),
            ),
            const SizedBox(height: 16),
            for (final set in catalog.practiceSets)
              _PracticeCard(
                set: set,
                catalog: catalog,
                isMastered: isMastered,
                player: player,
                progress: progress,
                clock: clock,
              ),
          ],
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.set,
    required this.catalog,
    required this.isMastered,
    required this.player,
    required this.progress,
    required this.clock,
  });

  final PracticeSet set;
  final CurriculumCatalog catalog;
  final bool Function(String competencyId) isMastered;
  final PracticeAudioPlayer? player;
  final ProgressStore? progress;
  final Clock? clock;

  @override
  Widget build(BuildContext context) {
    final earlyIntervals = set.id == 'PR-03';
    final minorDictation = set.id == 'PR-02';
    final scaleBuild = set.id == 'PR-05';
    final open = earlyIntervals ||
        (minorDictation && pr02CanStart(isMastered)) ||
        (set.mvpStatus.isMvp &&
            isTrainerOpen(set: set, catalog: catalog, isMastered: isMastered));
    final badge = minorDictation
        ? (open ? 'Открыто' : 'Закрыто')
        : !set.mvpStatus.isMvp
            ? 'Скоро'
            : earlyIntervals
                ? 'Стадии 1–8'
                : scaleBuild
                    ? (open ? 'Стадии 1–5' : 'Закрыто')
                    : (open ? 'Открыто' : 'Закрыто');
    final diagnostic = set.id == 'PR-08' || set.id == 'PR-09';
    return Card(
      key: Key('practice-${set.id}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(set.title),
            subtitle: Text(badge),
            enabled: open,
            onTap: open
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => openPractice(
                          setId: set.id,
                          player: player ?? SyntheticPracticeAudioPlayer(),
                          catalog: catalog,
                          progress: progress,
                          clock: clock,
                        ),
                      ),
                    );
                  }
                : null,
          ),
          if (diagnostic)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  final rules = AssessmentRules.fromConfig(catalog.config.raw);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          DiagnosticScreen(rules: rules, onFinished: (_) {}),
                    ),
                  );
                },
                child: const Text('Диагностика'),
              ),
            ),
        ],
      ),
    );
  }
}
