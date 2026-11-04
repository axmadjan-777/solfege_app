import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../coach/coach_layer.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import '../../curriculum/models/lesson.dart';
import '../../practice/progress/progress_rules.dart';

/// Уровни 0–4 — только MVP. Уровни 5–11 уже имеют проходимые карточки.
bool showsOnTheoryList(Lesson lesson) {
  if (lesson.level <= 4) return lesson.mvpStatus.isMvp;
  return lesson.level >= 5 && lesson.level <= 11;
}

class TheoryLevelScreen extends StatelessWidget {
  const TheoryLevelScreen({
    super.key,
    required this.catalog,
    required this.isMastered,
    this.needsReview,
    required this.onOpen,
    this.onRepair,
  });

  final CurriculumCatalog catalog;
  final bool Function(String competencyId) isMastered;
  final bool Function(String competencyId)? needsReview;
  final ValueChanged<Lesson> onOpen;
  final ValueChanged<Lesson>? onRepair;

  @override
  Widget build(BuildContext context) {
    final lessons = catalog.lessons.where(showsOnTheoryList).toList()
      ..sort((a, b) {
        final byLevel = a.level.compareTo(b.level);
        return byLevel != 0 ? byLevel : a.order.compareTo(b.order);
      });
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Теория', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(
          'Уровни 0–4 и карточки 5–11',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        for (final lesson in lessons)
          _LessonTile(
              lesson: lesson,
              catalog: catalog,
              isMastered: isMastered,
              needsReview: needsReview,
              onOpen: onOpen,
              onRepair: onRepair),
      ],
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.catalog,
    required this.isMastered,
    required this.needsReview,
    required this.onOpen,
    required this.onRepair,
  });

  final Lesson lesson;
  final CurriculumCatalog catalog;
  final bool Function(String competencyId) isMastered;
  final bool Function(String competencyId)? needsReview;
  final ValueChanged<Lesson> onOpen;
  final ValueChanged<Lesson>? onRepair;

  @override
  Widget build(BuildContext context) {
    final gate = lessonGate(
      lesson: lesson,
      catalog: catalog,
      isMastered: isMastered,
      needsReview: needsReview,
    );
    final label = switch (gate) {
      LessonGate.open => 'Открыто',
      LessonGate.locked => 'Закрыто',
      LessonGate.repair => 'Повторение',
    };
    final card = Card(
      key: Key('lesson-${lesson.id}'),
      child: ListTile(
        title: Text(lesson.title),
        subtitle: Text(label),
        enabled: gate == LessonGate.open ||
            (gate == LessonGate.repair && onRepair != null),
        onTap: switch (gate) {
          LessonGate.open => () {
              if (lesson.id == 'L00-01') {
                CoachScope.maybeOf(context)?.note('open-lesson');
              }
              onOpen(lesson);
            },
          LessonGate.repair when onRepair != null => () => onRepair!(lesson),
          _ => null,
        },
      ),
    );
    if (lesson.id != 'L00-01') return card;
    return CoachTarget(id: 'lesson-first', child: card);
  }
}
