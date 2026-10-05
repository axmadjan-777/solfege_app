import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../progress/progress_store.dart';
import '../trainers/error_queue.dart';

/// PR-16. Пустая очередь не рисуется как ошибка.
class ErrorQueueScreen extends StatelessWidget {
  const ErrorQueueScreen({super.key, required this.store, required this.onColdReview});

  final ProgressStore store;
  final ValueChanged<String> onColdReview;

  @override
  Widget build(BuildContext context) {
    final tags = ErrorQueue.openTags(store.book.attempts);
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
                        onPressed: () => onColdReview(tag),
                        child: Text(tag),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
