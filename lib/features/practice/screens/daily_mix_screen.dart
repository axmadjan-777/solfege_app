import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../trainers/daily_mix.dart';

/// Сводка плана. Если передан `taskBuilder`, «Начать» проводит задания по одному.
class DailyMixScreen extends StatefulWidget {
  const DailyMixScreen({super.key, required this.plan, this.taskBuilder});

  final DailyMixPlan plan;
  final Widget Function(MixItem item, ValueChanged<bool> onAnswered)?
      taskBuilder;

  @override
  State<DailyMixScreen> createState() => _DailyMixScreenState();
}

class _DailyMixScreenState extends State<DailyMixScreen> {
  var _started = false;
  var _index = 0;
  var _answered = false;
  var _correct = 0;

  bool get _finished => _started && _index >= widget.plan.items.length;

  void _accept(bool correct) {
    if (_answered) return;
    setState(() {
      _answered = true;
      if (correct) _correct += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_started && !_finished) return _task();
    return _summary();
  }

  Widget _task() {
    final last = _index + 1 >= widget.plan.items.length;
    return Stack(
      children: [
        KeyedSubtree(
          key: ValueKey('mix-$_index'),
          child: widget.taskBuilder!(widget.plan.items[_index], _accept),
        ),
        if (_answered)
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: AppColors.background,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                  onPressed: () => setState(() {
                    _index += 1;
                    _answered = false;
                  }),
                  child: Text(last ? 'Итог' : 'Дальше'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _summary() {
    final plan = widget.plan;
    final canStart =
        widget.taskBuilder != null && plan.items.isNotEmpty && !_finished;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ежедневный микс')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_finished)
              Text('Итог: верно $_correct из ${plan.items.length}'),
            Text('Заданий: ${plan.items.length}'),
            Text('Должное: ${plan.countOf(MixBucket.due)}'),
            Text('Недавнее: ${plan.countOf(MixBucket.recent)}'),
            Text('Лёгкое: ${plan.countOf(MixBucket.easy)}'),
            if (canStart) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => setState(() => _started = true),
                child: const Text('Начать'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
