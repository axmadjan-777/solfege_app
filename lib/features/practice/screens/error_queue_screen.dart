import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import '../../theory/level0/level0_plan.dart';
import '../../theory/level0/level0_player.dart';
import '../progress/practice_attempt.dart';
import '../progress/progress_store.dart';
import '../trainers/error_queue.dart';

/// PR-16. Пустая очередь не рисуется как ошибка.
/// Метка урока открывает этот урок. Верный повтор снимает метку.
class ErrorQueueScreen extends StatefulWidget {
  const ErrorQueueScreen({
    super.key,
    required this.store,
    required this.onColdReview,
    this.catalog,
  });

  final ProgressStore store;
  final ValueChanged<String> onColdReview;
  final CurriculumCatalog? catalog;

  @override
  State<ErrorQueueScreen> createState() => _ErrorQueueScreenState();
}

class _ErrorQueueScreenState extends State<ErrorQueueScreen> {
  @override
  Widget build(BuildContext context) {
    final tags = ErrorQueue.openTags(widget.store.book.attempts);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Работа над ошибками')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: tags.isEmpty
            ? const Text('Очередь пуста. Новых ошибок нет.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final tag in tags)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilledButton(
                        onPressed: () => _open(tag),
                        child: Text(_label(tag)),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  String _label(String tag) => widget.catalog?.findLesson(tag)?.title ?? tag;

  Future<void> _open(String tag) async {
    final lesson = widget.catalog?.findLesson(tag);
    if (lesson == null || widget.catalog == null) {
      widget.onColdReview(tag);
      return;
    }
    final catalog = widget.catalog!;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => Level0Player(
          plan: Level0Plan.fromLesson(lesson),
          onFinished: (result) {
            recordLessonResult(
              store: widget.store,
              catalog: catalog,
              lesson: lesson,
              correct: result.correct,
              total: result.total,
            );
            Navigator.of(routeContext).pop();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}
