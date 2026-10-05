import '../../curriculum/data/curriculum_catalog.dart';
import '../../curriculum/models/practice_set.dart';
import 'attempt.dart';
import 'clock.dart';
import 'progress_store.dart';

/// Одна попытка тренажёра пишется в книгу прогресса и не ставит `mastered`.
void recordPracticeAnswer({
  required ProgressStore store,
  required CurriculumCatalog catalog,
  required String setId,
  required bool correct,
}) {
  final set = catalog.practiceSets.firstWhere((item) => item.id == setId);
  final competencyId = competencyOf(set);
  store.recordSession(
    SessionDraft(
      competencyId: competencyId,
      sessionId: '$setId-${store.book.attempts.length}',
      correct: [correct],
      policy: catalog.config.policy(set.reviewRule),
      tonality: 'C',
      errorTag: correct ? '' : setId,
      itemSignature: setId,
    ),
  );
}

/// Холодная проверка из четырёх верных ответов. Раньше чем через 20 часов не пишется.
bool recordColdReview({
  required ProgressStore store,
  required CurriculumCatalog catalog,
  required String setId,
  required Clock clock,
}) {
  final set = catalog.practiceSets.firstWhere((item) => item.id == setId);
  final competencyId = competencyOf(set);
  final marked = store.snapshot(competencyId).provisionalAt;
  final ready = marked != null &&
      !clock.now().isBefore(marked.add(const Duration(hours: 20)));
  if (!ready) return false;
  store.recordSession(
    SessionDraft(
      competencyId: competencyId,
      sessionId: '$setId-cold-${store.book.attempts.length}',
      correct:
          List<bool>.filled(catalog.config.masteryRules.delayedMinItems, true),
      policy: catalog.config.policy(set.reviewRule),
      tonality: 'C',
      coldReview: true,
      itemSignature: '$setId-cold',
    ),
  );
  return store.snapshot(competencyId).status == CompetencyStatus.mastered;
}

String competencyOf(PracticeSet set) {
  for (final stage in set.stages) {
    if (stage.competencyIds.isNotEmpty) return stage.competencyIds.first;
  }
  return set.competencyIds.first;
}
