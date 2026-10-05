import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../curriculum/data/curriculum_asset_source.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import '../../practice/audio/practice_audio_player.dart';
import '../../practice/audio/synthetic_practice_audio_player.dart';
import '../../practice/progress/clock.dart';
import '../../practice/progress/practice_attempt.dart';
import '../../practice/progress/progress_store.dart';
import '../../practice/screens/practice_round_screen.dart';
import '../level0/level0_plan.dart';
import '../level0/level0_player.dart';
import 'theory_level_screen.dart';

class TheoryHomeScreen extends StatelessWidget {
  const TheoryHomeScreen({
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
      return _Home(
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
          return _Home(
              catalog: snapshot.data!,
              isMastered: _mastered,
              player: player,
              progress: progress,
              clock: clock);
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Не удалось загрузить теорию'));
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _Home extends StatelessWidget {
  const _Home(
      {required this.catalog,
      required this.isMastered,
      required this.player,
      required this.progress,
      required this.clock});

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
        child: TheoryLevelScreen(
          catalog: catalog,
          isMastered: isMastered,
          onOpen: (lesson) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Level0Player(
                  plan: Level0Plan.fromLesson(lesson),
                  onFinished: (result) {
                    if (progress != null) {
                      recordLessonResult(
                        store: progress!,
                        catalog: catalog,
                        lesson: lesson,
                        correct: result.correct,
                        total: result.total,
                      );
                    }
                    if (result.trainPracticeSetIds.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => openPractice(
                          setId: result.trainPracticeSetIds.first,
                          player: player ?? SyntheticPracticeAudioPlayer(),
                          catalog: catalog,
                          progress: progress,
                          clock: clock,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
