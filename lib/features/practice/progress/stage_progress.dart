import 'dart:convert';
import 'dart:math';

import '../../curriculum/data/curriculum_catalog.dart';
import '../../curriculum/models/curriculum_config.dart';
import '../../curriculum/models/practice_set.dart';
import '../trainers/stage_catalog.dart';
import 'attempt.dart';
import 'progress_store.dart';

CompetencyProgressPolicy stageCompetencyPolicy({
  required CurriculumCatalog catalog,
  required PracticeStage stage,
  required String competencyId,
}) {
  if (!stage.competencyIds.contains(competencyId)) {
    throw ArgumentError.value(competencyId, 'competencyId');
  }
  final competency = catalog.competency(competencyId);
  final base = catalog.config.masteryRules;
  final cold = stage.coldReview;
  final stageMinItems = (cold?['min_items'] as num?)?.toInt() ?? 0;
  final stageAccuracy = (cold?['min_accuracy'] as num?)?.toDouble() ?? 0;
  return CompetencyProgressPolicy(
    policy: catalog.config.policy(
      cold?['policy_id'] as String? ?? competency.coldReviewPolicyId,
    ),
    rules: MasteryRules(
      statuses: base.statuses,
      immediateMinAccuracy:
          max(base.immediateMinAccuracy, competency.immediateThreshold),
      immediateWindow:
          max(base.immediateWindow, competency.initialPassMinItems),
      immediateMaxCriticalErrors: base.immediateMaxCriticalErrors,
      delayedMinAccuracy: max(
        max(base.delayedMinAccuracy, competency.delayedThreshold),
        max(competency.coldReviewMinAccuracy, stageAccuracy),
      ),
      delayedMinItems: max(
        max(base.delayedMinItems, competency.coldReviewMinItems),
        stageMinItems,
      ),
      transferMinAccuracy:
          max(base.transferMinAccuracy, competency.transferThreshold),
      transferDimensions: base.transferDimensions,
      demotionWindow: competency.demotionWindow ?? base.demotionWindow,
      demotionAccuracyBelow:
          competency.demotionAccuracyBelow ?? base.demotionAccuracyBelow,
    ),
  );
}

String? stageReviewBlockReason({
  required CurriculumCatalog catalog,
  required PracticeSet set,
  required int stage,
  required String competencyId,
  required ProgressStore store,
  required DateTime now,
}) {
  final unavailable = stageUnavailableReason(set.id, stage);
  if (unavailable != null) return unavailable;
  final spec = set.stages.firstWhere((item) => item.stage == stage);
  final profile = stageCompetencyPolicy(
      catalog: catalog, stage: spec, competencyId: competencyId);
  final snapshot = store.snapshot(competencyId);
  if (snapshot.status == CompetencyStatus.mastered) return 'Навык уже освоен';
  final provisionalAt = snapshot.provisionalAt;
  if (snapshot.status != CompetencyStatus.provisionallyPassed ||
      provisionalAt == null) {
    return 'Сначала завершите тренировку этого навыка';
  }
  final readyAt = provisionalAt
      .add(Duration(hours: profile.policy.firstDelayRangeHours.$1));
  if (now.isBefore(readyAt)) {
    final minutes = readyAt.difference(now).inSeconds / 60;
    return 'Холодная проверка через ${minutes.ceil()} мин';
  }
  return null;
}

/// Один ответ остаётся одной попыткой, даже если он совместно проверяет два навыка.
/// Контекстные задания без проверяемой компетенции влияют только на сдачу стадии.
bool recordStageAnswer({
  required ProgressStore store,
  required CurriculumCatalog catalog,
  required PracticeSet set,
  required int stage,
  required StageTask task,
  required bool correct,
  required String sessionId,
  String? reviewCompetencyId,
  required DateTime now,
  int responseMs = 0,
}) {
  final spec = set.stages.firstWhere((item) => item.stage == stage);
  final ids = task.competencyIds.toSet().toList();
  if (!spec.mvpStatus.isMvp || stageUnavailableReason(set.id, stage) != null) {
    throw StateError('Эта стадия пока недоступна');
  }
  if (ids.any((id) => !spec.competencyIds.contains(id))) {
    throw ArgumentError('Задание содержит компетенцию другой стадии');
  }
  if (ids.isEmpty) return false;
  if (reviewCompetencyId != null) {
    if (ids.length != 1 || ids.single != reviewCompetencyId) {
      throw ArgumentError('Холодная проверка оценивает только выбранный навык');
    }
    final started = store.book.attempts.any((attempt) =>
        attempt.coldReview &&
        attempt.sessionId == sessionId &&
        attempt.competencyIds.contains(reviewCompetencyId));
    if (!started) {
      final blocked = stageReviewBlockReason(
        catalog: catalog,
        set: set,
        stage: stage,
        competencyId: reviewCompetencyId,
        store: store,
        now: now,
      );
      if (blocked != null) throw StateError(blocked);
    }
  }
  final profiles = {
    for (final id in ids)
      id: stageCompetencyPolicy(
          catalog: catalog, stage: spec, competencyId: id),
  };
  store.recordSession(SessionDraft(
    competencyId: ids.first,
    competencyIds: ids,
    competencyPolicies: profiles,
    sessionId: sessionId,
    correct: [correct],
    responseMs: [responseMs],
    policy: catalog.config.policy(set.reviewRule),
    tonality: task.tonality,
    coldReview: reviewCompetencyId != null,
    errorTag: set.id,
    itemSignature: jsonEncode([
      set.id,
      stage,
      task.answer,
      task.soundedMidi,
      task.visible,
      task.tonality,
      task.gapMs,
      task.beats,
    ]),
  ));
  return true;
}

/// В распознавании проверяем и целевой стимул, и контрасты: постоянный ответ
/// одним названием не должен сдавать холодную проверку.
StageSessionPlan buildStageReviewSession({
  required CurriculumCatalog catalog,
  required PracticeSet set,
  required int stage,
  required String competencyId,
  required int seed,
}) {
  final spec = set.stages.firstWhere((item) => item.stage == stage);
  final profile = stageCompetencyPolicy(
      catalog: catalog, stage: spec, competencyId: competencyId);
  final count = profile.rules.delayedMinItems;
  final positives = <StageTask>[];
  final contrasts = <StageTask>[];
  final recognition =
      set.id == 'PR-01' && competencyId.startsWith('ear.degree.major.') ||
          set.id == 'PR-03' && stage == 3 ||
          set.id == 'PR-06' && competencyId.startsWith('ear.triad.');
  for (var round = 0; round < 80; round++) {
    final plan = buildStageSession(set: set, stage: stage, seed: seed + round);
    for (final task in plan.tasks) {
      if (task.competencyIds.contains(competencyId)) {
        positives.add(task);
      } else if (recognition) {
        contrasts.add(task);
      }
    }
    if (positives.length >= count &&
        (!recognition || contrasts.length >= count)) {
      break;
    }
  }
  if (positives.length < count || recognition && contrasts.isEmpty) {
    throw StateError('Для этого навыка пока нет достаточной холодной проверки');
  }
  final positiveCount = recognition ? (count / 2).ceil() : count;
  final tasks = <StageTask>[
    ...positives.take(positiveCount),
    ...contrasts.take(count - positiveCount),
  ]..shuffle(Random(seed));
  return StageSessionPlan(
    setId: set.id,
    stage: stage,
    title: 'Холодная проверка: ${catalog.competency(competencyId).title}',
    tasks: [
      for (final task in tasks) task.withCompetencies([competencyId])
    ],
    minAccuracy: profile.rules.delayedMinAccuracy,
    minItems: count,
    correctFeedback: 'Ответ учтён в проверке выбранного навыка',
    errorFeedback: 'После проверки можно вернуться к тренировке',
  );
}
