import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Фразы вместо индикатора, пока модель думает.
const thinkingPhrases = [
  'Пиликаю на скрипке',
  'Шуршу нотами',
  'Собираю оркестр',
  'Настраиваю камертон',
  'Ищу потерянный такт',
  'Перелистываю партитуру',
  'Считаю до четырёх',
  'Договариваюсь с дирижёром',
];

class ThinkingBubble extends StatefulWidget {
  const ThinkingBubble({
    super.key,
    this.period = const Duration(milliseconds: 1400),
    this.phrases = thinkingPhrases,
  });

  final Duration period;
  final List<String> phrases;

  @override
  State<ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<ThinkingBubble> {
  Timer? _timer;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.period, (_) {
      if (!mounted || widget.phrases.length < 2) return;
      setState(() => _index = (_index + 1) % widget.phrases.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phrase = widget.phrases[_index];
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('ai_thinking'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          phrase,
          key: Key('ai_thinking_$_index'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ),
    );
  }
}
