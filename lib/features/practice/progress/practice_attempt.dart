import '../../curriculum/data/curriculum_catalog.dart';
import '../../curriculum/models/lesson.dart';
import '../../curriculum/models/practice_set.dart';
import 'progress_store.dart';
import 'stage_progress.dart';

/// Одна попытка тренажёра пишется в книгу прогресса и не ставит `mastered`.
void recordPracticeAnswer({
  required ProgressStore store,
  required CurriculumCatalog catalog,
  required String setId,
  required bool correct,
  bool coldReview = false,
  String? sessionId,
  String tonality = 'C',
}) {
  final set = catalog.practiceSets.firstWhere((item) => item.id == setId);
  final competencyId = competencyOf(set);
  final profile = coldReview ? practiceReviewPolicy(catalog, setId) : null;
  store.recordSession(
    SessionDraft(
      competencyId: competencyId,
      competencyPolicies: profile == null ? const {} : {competencyId: profile},
      sessionId: sessionId ?? '$setId-${store.book.attempts.length}',
      correct: [correct],
      policy: catalog.config.policy(set.reviewRule),
      tonality: tonality,
      coldReview: coldReview,
      errorTag: setId,
      itemSignature: setId,
    ),
  );
}

/// Прежний вход использует те же ограничения каталога, что и проверка стадии.
CompetencyProgressPolicy practiceReviewPolicy(
    CurriculumCatalog catalog, String setId) {
  final set = catalog.practiceSet(setId);
  final id = competencyOf(set);
  final stage =
      set.stages.firstWhere((stage) => stage.competencyIds.contains(id));
  return stageCompetencyPolicy(
      catalog: catalog, stage: stage, competencyId: id);
}

/// Итог урока пишется в ту же книгу, что и ответ тренажёра. Короткий урок не ставит `mastered`.
void recordLessonResult({
  required ProgressStore store,
  required CurriculumCatalog catalog,
  required Lesson lesson,
  required int correct,
  required int total,
}) {
  if (total <= 0) return;
  final missed = total - correct;
  store.recordSession(
    SessionDraft(
      competencyId: lesson.primaryCompetency,
      sessionId: '${lesson.id}-${store.book.attempts.length}',
      correct: [
        ...List<bool>.filled(correct, true),
        ...List<bool>.filled(missed, false)
      ],
      policy: catalog.config.policy(lesson.coldReviewPolicyId),
      tonality: 'C',
      errorTag: lesson.id,
      itemSignature: lesson.id,
    ),
  );
}

String competencyOf(PracticeSet set) {
  for (final stage in set.stages) {
    if (stage.competencyIds.isNotEmpty) return stage.competencyIds.first;
  }
  return set.competencyIds.first;
}
