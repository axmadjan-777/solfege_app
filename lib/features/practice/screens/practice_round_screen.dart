import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import '../audio/practice_audio_player.dart';
import '../progress/attempt.dart';
import '../progress/clock.dart';
import '../progress/practice_attempt.dart';
import '../progress/progress_store.dart';
import 'practice_followup.dart';

/// Серия ответов. Окно из 12 при точности 0.85 даёт `provisionally_passed`.
/// Падение последних 6 ниже 0.6 просит повторить. Новое окно 0.85 возвращает сдачу.
/// `mastered` ставит только холодная проверка спустя 20 часов.
class PracticeRoundScreen extends StatefulWidget {
  const PracticeRoundScreen({
    super.key,
    required this.setId,
    required this.player,
    required this.catalog,
    required this.progress,
    required this.clock,
  });

  final String setId;
  final PracticeAudioPlayer player;
  final CurriculumCatalog catalog;
  final ProgressStore progress;
  final Clock clock;

  @override
  State<PracticeRoundScreen> createState() => _PracticeRoundScreenState();
}

class _PracticeRoundScreenState extends State<PracticeRoundScreen> {
  var _round = 0;
  var _answered = false;
  var _coldLeft = 0;
  String? _coldSession;
  String? _notice;
  var _tonality = 'C';

  String get _competency => competencyOf(
      widget.catalog.practiceSets.firstWhere((set) => set.id == widget.setId));

  CompetencyStatus get _status => widget.progress.snapshot(_competency).status;

  void _advance() {
    setState(() {
      _round += 1;
      _answered = false;
      if (_coldLeft == 0) _notice = null;
    });
  }

  void _repeat() {
    setState(() {
      _round += 1;
      _answered = false;
      _notice = null;
    });
  }

  void _coldReview() {
    final marked = widget.progress.snapshot(_competency).provisionalAt;
    final ready = marked != null &&
        !widget.clock.now().isBefore(marked.add(const Duration(hours: 20)));
    if (!ready) {
      setState(() => _notice = 'Рано');
      return;
    }
    setState(() {
      _coldLeft = widget.catalog.config.masteryRules.delayedMinItems;
      _coldSession =
          '${widget.setId}-cold-${widget.clock.now().microsecondsSinceEpoch}';
      _notice = 'Холодная проверка';
      _round += 1;
      _answered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stability = widget.progress.snapshot(_competency).stability;
    final showSaved = !_answered &&
        (stability.sessions.isNotEmpty || _status != CompetencyStatus.locked);
    return Stack(
      children: [
        KeyedSubtree(
          key: ValueKey('${widget.setId}-$_round'),
          child: practiceSetScreen(
            setId: widget.setId,
            player: widget.player,
            catalog: widget.catalog,
            progress: widget.progress,
            coldReview: _coldLeft > 0,
            sessionId: _coldLeft > 0 ? _coldSession : null,
            tonality: _tonality,
            clock: widget.clock,
            onAnswered: (_) {
              setState(() {
                if (_coldLeft > 0) _coldLeft -= 1;
                _answered = true;
                if (_coldLeft == 0 &&
                    _status != CompetencyStatus.provisionallyPassed) {
                  _notice = null;
                }
              });
            },
          ),
        ),
        if (showSaved)
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(practiceStatusLabel(_status)),
                      Text(stabilityLabel(stability)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_answered)
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: AppColors.background,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(practiceStatusLabel(_status)),
                    Text(stabilityLabel(
                        widget.progress.snapshot(_competency).stability)),
                    if (_notice != null) Text(_notice!),
                    const SizedBox(height: 12),
                    if (_status == CompetencyStatus.provisionallyPassed)
                      FilledButton(
                          onPressed: _coldReview,
                          child: const Text('Холодная проверка')),
                    if (_status != CompetencyStatus.mastered) ...[
                      if (_coldLeft == 0)
                        FilledButton(
                            onPressed: _repeat, child: const Text('Повторить')),
                      FilledButton(
                        onPressed: () => setState(
                            () => _tonality = _tonality == 'C' ? 'G' : 'C'),
                        child: Text(
                            'Тональность: ${_tonality == 'C' ? 'до' : 'соль'}'),
                      ),
                      FilledButton(
                          onPressed: _advance, child: const Text('Следующее')),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Widget openPractice({
  required String setId,
  required PracticeAudioPlayer player,
  required CurriculumCatalog catalog,
  ProgressStore? progress,
  Clock? clock,
}) {
  if (progress == null) {
    return practiceSetScreen(
        setId: setId, player: player, catalog: catalog, clock: clock);
  }
  return PracticeRoundScreen(
    setId: setId,
    player: player,
    catalog: catalog,
    progress: progress,
    clock: clock ?? const SystemClock(),
  );
}

String stabilityLabel(Stability stability) {
  if (stability.reached) return 'Стабильно';
  if (stability.sessions.length >= 3) return 'Нужна другая тональность';
  return 'Устойчивость ${stability.sessions.length}/3';
}

String practiceStatusLabel(CompetencyStatus status) {
  return switch (status) {
    CompetencyStatus.provisionallyPassed => 'Предварительно сдано',
    CompetencyStatus.mastered => 'Освоено',
    CompetencyStatus.needsReview => 'Нужно повторить',
    CompetencyStatus.practicing => 'В практике',
    _ => 'Закрыто',
  };
}
