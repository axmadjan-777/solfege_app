import '../../curriculum/data/curriculum_catalog.dart';
import '../../curriculum/models/practice_set.dart';
import 'progress_store.dart';

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
  store.recordSession(
    SessionDraft(
      competencyId: competencyId,
      sessionId: sessionId ?? '$setId-${store.book.attempts.length}',
      correct: [correct],
      policy: catalog.config.policy(set.reviewRule),
      tonality: tonality,
      coldReview: coldReview,
      errorTag: correct ? '' : setId,
      itemSignature: setId,
    ),
  );
}

String competencyOf(PracticeSet set) {
  for (final stage in set.stages) {
    if (stage.competencyIds.isNotEmpty) return stage.competencyIds.first;
  }
  return set.competencyIds.first;
}
