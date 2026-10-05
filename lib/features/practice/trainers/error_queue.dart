import '../../curriculum/data/curriculum_catalog.dart';
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
    return [
      for (final entry in latestCorrect.entries)
        if (!entry.value) entry.key
    ];
  }

  /// Только метки уроков и тренажёров этой линии навыка.
  static List<String> openTagsOnTrack({
    required List<AttemptRecord> attempts,
    required CurriculumCatalog catalog,
    required String skillTrack,
  }) {
    return [
      for (final tag in openTags(attempts))
        if (trackOf(catalog, tag) == skillTrack) tag,
    ];
  }

  static String? trackOf(CurriculumCatalog catalog, String tag) {
    final lesson = catalog.findLesson(tag);
    if (lesson != null) return lesson.skillTrack;
    for (final set in catalog.practiceSets) {
      if (set.id == tag) return set.skillTrack;
    }
    return null;
  }

  static bool repairInsteadOfNewLesson(int needsReviewInTrack) =>
      needsReviewInTrack >= 3;
}
