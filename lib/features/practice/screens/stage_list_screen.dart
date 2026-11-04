import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import '../../curriculum/models/practice_set.dart';
import '../audio/practice_audio_player.dart';
import '../progress/clock.dart';
import '../progress/attempt.dart';
import '../progress/progress_store.dart';
import '../progress/stage_progress.dart';
import '../trainers/stage_catalog.dart';
import 'stage_run_screen.dart';
import 'practice_round_screen.dart';

/// Список стадий тренажёра. Вне MVP — «Скоро», следующая ждёт сдачи предыдущей.
class StageListScreen extends StatefulWidget {
  const StageListScreen({
    super.key,
    required this.set,
    required this.player,
    required this.catalog,
    this.progress,
    this.clock,
  });

  final PracticeSet set;
  final PracticeAudioPlayer player;
  final CurriculumCatalog catalog;
  final ProgressStore? progress;
  final Clock? clock;

  @override
  State<StageListScreen> createState() => _StageListScreenState();
}

class _StageListScreenState extends State<StageListScreen> {
  Set<int> get _passed {
    final stages = widget.progress?.book.passedStages[widget.set.id];
    if (stages == null) return const {};
    return stages.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final offers = stageOffers(widget.set, _passed);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.set.title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (widget.progress != null &&
              offers.any((offer) => offer.access != StageAccess.soon))
            ListTile(
              key: const Key('practice-review'),
              title: const Text('Повторение и холодная проверка'),
              subtitle: const Text(
                'Проверка освоения после отложенного повторения',
              ),
              onTap: _openReview,
            ),
          for (final offer in offers) ...[
            ListTile(
              key: Key('stage-${widget.set.id}-${offer.stage}'),
              title: Text(offer.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_label(offer.access)),
                  if (offer.unavailableReason != null)
                    Text(offer.unavailableReason!),
                ],
              ),
              enabled: offer.access == StageAccess.open,
              onTap: offer.access == StageAccess.open
                  ? () => _open(offer.stage)
                  : null,
            ),
            if (offer.access == StageAccess.open)
              ..._reviewActions(offer.stage),
          ],
        ],
      ),
    );
  }

  List<Widget> _reviewActions(int stage) {
    final store = widget.progress;
    if (store == null) return const [];
    final spec = widget.set.stages.firstWhere((item) => item.stage == stage);
    return [
      for (final id in spec.competencyIds)
        if (store.snapshot(id).status == CompetencyStatus.provisionallyPassed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton(
                  key: Key('stage-review-${widget.set.id}-$stage-$id'),
                  onPressed: stageReviewBlockReason(
                            catalog: widget.catalog,
                            set: widget.set,
                            stage: stage,
                            competencyId: id,
                            store: store,
                            now: (widget.clock ?? const SystemClock()).now(),
                          ) ==
                          null
                      ? () => _open(stage, reviewCompetencyId: id)
                      : null,
                  child: Text(
                      'Холодная проверка: ${widget.catalog.competency(id).title}'),
                ),
                if (stageReviewBlockReason(
                  catalog: widget.catalog,
                  set: widget.set,
                  stage: stage,
                  competencyId: id,
                  store: store,
                  now: (widget.clock ?? const SystemClock()).now(),
                )
                    case final String reason)
                  Text(reason),
              ],
            ),
          ),
    ];
  }

  Future<void> _openReview() async {
    final progress = widget.progress;
    if (progress == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeRoundScreen(
          setId: widget.set.id,
          player: widget.player,
          catalog: widget.catalog,
          progress: progress,
          clock: widget.clock ?? const SystemClock(),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _open(int stage, {String? reviewCompetencyId}) async {
    final attempts = widget.progress?.book.attempts.length ?? 0;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StageRunScreen(
          set: widget.set,
          stage: stage,
          player: widget.player,
          catalog: widget.catalog,
          progress: widget.progress,
          clock: widget.clock ?? const SystemClock(),
          seed: stageSessionSeed(widget.set.id, stage, attempts),
          reviewCompetencyId: reviewCompetencyId,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  String _label(StageAccess access) {
    return switch (access) {
      StageAccess.open => 'Открыто',
      StageAccess.locked => 'Закрыто',
      StageAccess.soon => 'Скоро',
    };
  }
}
