import '../progress/attempt.dart';

/// Очередь группируется по `error_tag`. Разные карточки с одним тегом — одна запись.
class ErrorQueue {
  const ErrorQueue._();

  static List<String> openTags(List<AttemptRecord> attempts) {
    final latestCorrect = <String, bool>{};
    for (final attempt in attempts) {
      if (attempt.errorTag.isEmpty) continue;
      latestCorrect[attempt.errorTag] = attempt.isCorrect;
    }
    return [for (final entry in latestCorrect.entries) if (!entry.value) entry.key];
  }

  static bool repairInsteadOfNewLesson(int needsReviewInTrack) => needsReviewInTrack >= 3;
}
