import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import '../../curriculum/models/practice_set.dart';
import '../audio/practice_audio_player.dart';
import '../progress/clock.dart';
import '../progress/progress_store.dart';
import '../trainers/stage_catalog.dart';
import 'stage_run_screen.dart';

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
          for (final offer in offers)
            ListTile(
              key: Key('stage-${widget.set.id}-${offer.stage}'),
              title: Text(offer.title),
              subtitle: Text(_label(offer.access)),
              enabled: offer.access == StageAccess.open,
              onTap: offer.access == StageAccess.open
                  ? () => _open(offer.stage)
                  : null,
            ),
        ],
      ),
    );
  }

  Future<void> _open(int stage) async {
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
