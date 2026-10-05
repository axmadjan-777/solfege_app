import '../../curriculum/data/curriculum_catalog.dart';
import '../../curriculum/models/lesson.dart';
import '../../curriculum/models/practice_set.dart';
import '../trainers/error_queue.dart';
import 'attempt.dart';

/// Шаг `interval_days`: ошибка назад, успешный перенос вперёд.
class ReviewStep {
  const ReviewStep({required this.index, required this.dueAt});

  final int index;
  final DateTime dueAt;

  static ReviewStep advance({
    required List<int> intervalDays,
    required int index,
    required DateTime now,
    required bool incorrect,
    required bool transfer,
  }) {
    var next = index;
    if (incorrect) {
      next = index > 0 ? index - 1 : 0;
    } else if (transfer) {
      next = index + 1 < intervalDays.length ? index + 1 : index;
    }
    return ReviewStep(
        index: next, dueAt: now.add(Duration(days: intervalDays[next])));
  }
}

class MasteryDecision {
  const MasteryDecision(
      {required this.status, required this.markedProvisionalAt});

  final CompetencyStatus status;
  final DateTime? markedProvisionalAt;

  /// Потолок тренировочной сессии — `provisionally_passed`.
  /// `mastered` ставит только cold review не раньше чем через 20 часов.
  static MasteryDecision evaluate({
    required CompetencyStatus current,
    required DateTime? provisionalAt,
    required List<AttemptRecord> attempts,
    required DateTime now,
    required bool coldReview,
    required double immediateMinAccuracy,
    required int immediateWindow,
    required int immediateMaxCriticalErrors,
    required double delayedMinAccuracy,
    required int delayedMinItems,
    required double demotionAccuracyBelow,
    required int demotionWindow,
  }) {
    final demoted = _recentAccuracy(attempts, demotionWindow);
    if (demoted != null && demoted < demotionAccuracyBelow) {
      return MasteryDecision(
          status: CompetencyStatus.needsReview,
          markedProvisionalAt: provisionalAt);
    }

    if (coldReview) {
      final waited = provisionalAt != null &&
          !now.isBefore(provisionalAt.add(const Duration(hours: 20)));
      final coldAttempts = _currentColdReview(attempts);
      final coldAccuracy = _sessionAccuracy(coldAttempts);
      final coldCount = coldAttempts.length;
      final complete = coldCount >= delayedMinItems && coldAccuracy != null;
      if (waited && complete && coldAccuracy >= delayedMinAccuracy) {
        return MasteryDecision(
            status: CompetencyStatus.mastered,
            markedProvisionalAt: provisionalAt);
      }
      if (waited && complete) {
        return const MasteryDecision(
            status: CompetencyStatus.needsReview, markedProvisionalAt: null);
      }
      return MasteryDecision(
          status: current, markedProvisionalAt: provisionalAt);
    }

    final window = _last(attempts, immediateWindow);
    final accuracy = _recentAccuracy(attempts, immediateWindow);
    final critical = window.where((a) => a.critical && !a.isCorrect).length;
    if (window.length >= immediateWindow &&
        accuracy != null &&
        accuracy >= immediateMinAccuracy &&
        critical <= immediateMaxCriticalErrors) {
      final capped = current == CompetencyStatus.mastered
          ? CompetencyStatus.mastered
          : CompetencyStatus.provisionallyPassed;
      return MasteryDecision(
        status: capped,
        markedProvisionalAt: provisionalAt ?? now,
      );
    }

    if (current == CompetencyStatus.locked) {
      return MasteryDecision(
          status: CompetencyStatus.practicing,
          markedProvisionalAt: provisionalAt);
    }
    return MasteryDecision(status: current, markedProvisionalAt: provisionalAt);
  }

  static List<AttemptRecord> _currentColdReview(List<AttemptRecord> attempts) {
    final cold = attempts.where((attempt) => attempt.coldReview).toList();
    if (cold.isEmpty) return const [];
    final sessionId = cold.last.sessionId;
    return cold.where((attempt) => attempt.sessionId == sessionId).toList();
  }

  static List<AttemptRecord> _last(List<AttemptRecord> attempts, int count) {
    if (attempts.length <= count) return attempts;
    return attempts.sublist(attempts.length - count);
  }

  static double? _recentAccuracy(List<AttemptRecord> attempts, int count) {
    final window = _last(attempts, count);
    if (window.length < count) return null;
    final correct = window.where((a) => a.isCorrect).length;
    return correct / window.length;
  }

  static double? _sessionAccuracy(Iterable<AttemptRecord> attempts) {
    final list = attempts.toList();
    if (list.isEmpty) return null;
    return list.where((a) => a.isCorrect).length / list.length;
  }
}

class StabilityUpdate {
  const StabilityUpdate._();

  static Stability addSession({
    required Stability current,
    required DateTime at,
    required String tonality,
    required bool successful,
  }) {
    if (!successful) return current;
    final previous = current.sessions.isEmpty ? null : current.sessions.last.at;
    if (previous != null &&
        at.difference(previous) < const Duration(hours: 20)) {
      return current;
    }
    return current.add(StabilitySession(at: at, tonality: tonality));
  }
}

enum LessonGate { open, locked, repair }

/// Три `needs_review` на линии навыка закрывают новый урок: ученик остаётся на повторении.
LessonGate lessonGate({
  required Lesson lesson,
  required CurriculumCatalog catalog,
  required bool Function(String competencyId) isMastered,
  bool Function(String competencyId)? needsReview,
}) {
  if (!isLessonOpen(lesson: lesson, catalog: catalog, isMastered: isMastered)) {
    return LessonGate.locked;
  }
  if (needsReview == null) return LessonGate.open;
  final waiting = catalog.competencies
      .where((competency) =>
          competency.skillTrack == lesson.skillTrack &&
          needsReview(competency.id))
      .length;
  if (ErrorQueue.repairInsteadOfNewLesson(waiting)) return LessonGate.repair;
  return LessonGate.open;
}

/// Урок открыт, когда `primary_competency` каждой предпосылки-урока в `mastered`.
bool isLessonOpen({
  required Lesson lesson,
  required CurriculumCatalog catalog,
  required bool Function(String competencyId) isMastered,
}) {
  for (final ref in lesson.prerequisites) {
    final earlierId = ref.lessonId;
    if (earlierId == null) continue;
    final earlier = catalog.findLesson(earlierId);
    if (earlier == null || !isMastered(earlier.primaryCompetency)) return false;
  }
  return true;
}

/// Тренажёр открыт, когда освоены opener-уроки из списка 56. Уроки вне MVP замок не держат.
bool isTrainerOpen({
  required PracticeSet set,
  required CurriculumCatalog catalog,
  required bool Function(String competencyId) isMastered,
}) {
  for (final lessonId in set.openedByLessonIds) {
    final lesson = catalog.findLesson(lessonId);
    if (lesson == null || !lesson.mvpStatus.isMvp) continue;
    if (!isMastered(lesson.primaryCompetency)) return false;
  }
  return true;
}
