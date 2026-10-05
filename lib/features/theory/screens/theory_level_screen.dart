import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import '../../curriculum/models/lesson.dart';
import '../../practice/progress/progress_rules.dart';

class TheoryLevelScreen extends StatelessWidget {
  const TheoryLevelScreen({
    super.key,
    required this.catalog,
    required this.isMastered,
    required this.onOpen,
  });

  final CurriculumCatalog catalog;
  final bool Function(String competencyId) isMastered;
  final ValueChanged<Lesson> onOpen;

  @override
  Widget build(BuildContext context) {
    final lessons = catalog.lessons.where((lesson) => lesson.level <= 1 && lesson.mvpStatus.isMvp).toList()
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
          'Уровни 0 и 1',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        for (final lesson in lessons)
          _LessonTile(lesson: lesson, catalog: catalog, isMastered: isMastered, onOpen: onOpen),
      ],
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.catalog,
    required this.isMastered,
    required this.onOpen,
  });

  final Lesson lesson;
  final CurriculumCatalog catalog;
  final bool Function(String competencyId) isMastered;
  final ValueChanged<Lesson> onOpen;

  @override
  Widget build(BuildContext context) {
    final open = isLessonOpen(lesson: lesson, catalog: catalog, isMastered: isMastered);
    return Card(
      key: Key('lesson-${lesson.id}'),
      child: ListTile(
        title: Text(lesson.title),
        subtitle: Text(open ? 'Открыто' : 'Закрыто'),
        enabled: open,
        onTap: open ? () => onOpen(lesson) : null,
      ),
    );
  }
}
