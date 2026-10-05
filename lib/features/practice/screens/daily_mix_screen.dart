import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../progress/clock.dart';
import '../trainers/daily_mix.dart';

/// Сводка плана. Если передан `taskBuilder`, «Начать» проводит задания по одному.
class DailyMixScreen extends StatefulWidget {
  const DailyMixScreen({
    super.key,
    required this.plan,
    this.taskBuilder,
    this.clock,
    this.sessionLimit,
    this.onSameSessionReturn,
  });

  final DailyMixPlan plan;
  final Widget Function(MixItem item, ValueChanged<bool> onAnswered)?
      taskBuilder;
  final Clock? clock;
  final Duration? sessionLimit;
  final void Function(String tag)? onSameSessionReturn;

  @override
  State<DailyMixScreen> createState() => _DailyMixScreenState();
}

class _DailyMixScreenState extends State<DailyMixScreen> {
  var _started = false;
  var _index = 0;
  var _answered = false;
  var _correct = 0;
  var _completed = 0;
  var _stoppedForTime = false;
  DateTime? _startedAt;
  final _tomorrow = <String>[];
  late List<MixItem> _items;

  @override
  void initState() {
    super.initState();
    _items = [...widget.plan.items];
  }

  bool get _finished => _started && _index >= _items.length;

  bool get _returnItem => _index >= widget.plan.items.length;

  bool get _timeUp {
    final start = _startedAt;
    final clock = widget.clock;
    final limit = widget.sessionLimit;
    if (start == null || clock == null || limit == null) return false;
    return !clock.now().isBefore(start.add(limit));
  }

  void _accept(bool correct) {
    if (_answered) return;
    final tag = _returnItem ? _items[_index].id : null;
    setState(() {
      _answered = true;
      _completed += 1;
      if (correct) {
        _correct += 1;
      }
      if (tag != null && !_tomorrow.contains(tag)) {
        _tomorrow.add(tag);
      }
      _items = appendSameSessionReturn(
        planned: widget.plan.items,
        running: _items,
        index: _index,
        correct: correct,
      );
    });
    if (tag != null) widget.onSameSessionReturn?.call(tag);
  }

  @override
  Widget build(BuildContext context) {
    if (_started && !_finished) return _task();
    return _summary();
  }

  Widget _task() {
    final item = _items[_index];
    final last = _index + 1 >= _items.length;
    return Stack(
      children: [
        KeyedSubtree(
          key: ValueKey('mix-${item.id}-$_index'),
          child: widget.taskBuilder!(item, _accept),
        ),
        if (_returnItem || _answered)
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              ignoring: !_answered,
              child: Material(
                color: AppColors.background,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_returnItem) const Text('Повтор ошибки'),
                      if (_answered) ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => setState(() {
                            if (_timeUp && !last) {
                              _stoppedForTime = true;
                              _index = _items.length;
                              return;
                            }
                            _index += 1;
                            _answered = false;
                          }),
                          child: Text(last || _timeUp ? 'Итог' : 'Дальше'),
                        ),
                      ],
                    ],
                  ),
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
            if (_finished) ...[
              if (_stoppedForTime) const Text('Время вышло'),
              Text('Итог: верно $_correct из $_completed'),
              for (final tag in _tomorrow) Text('Завтра: $tag'),
            ],
            Text('Заданий: ${plan.items.length}'),
            Text('Должное: ${plan.countOf(MixBucket.due)}'),
            Text('Недавнее: ${plan.countOf(MixBucket.recent)}'),
            Text('Лёгкое: ${plan.countOf(MixBucket.easy)}'),
            if (canStart) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => setState(() {
                  _started = true;
                  _startedAt = widget.clock?.now();
                }),
                child: const Text('Начать'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
