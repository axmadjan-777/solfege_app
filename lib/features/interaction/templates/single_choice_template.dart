import 'package:flutter/material.dart';

/// T01 — выбор. T02 — тот же выбор после прослушивания.
class SingleChoiceTemplate extends StatelessWidget {
  const SingleChoiceTemplate({
    super.key,
    required this.templateId,
    required this.prompt,
    required this.options,
    required this.onSelect,
    this.showHint = false,
    this.onHint,
    this.onPlay,
  });

  final String templateId;
  final String prompt;
  final List<String> options;
  final ValueChanged<int> onSelect;
  final bool showHint;
  final VoidCallback? onHint;
  final VoidCallback? onPlay;

  bool get isAudio => templateId == 'T02';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(prompt, style: Theme.of(context).textTheme.titleMedium),
        if (isAudio) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onPlay, child: const Text('Слушать')),
        ],
        const SizedBox(height: 12),
        for (var i = 0; i < options.length; i++) ...[
          FilledButton(
            onPressed: () => onSelect(i),
            child: Text(options[i]),
          ),
          const SizedBox(height: 8),
        ],
        if (showHint)
          TextButton(onPressed: onHint, child: const Text('Подсказка')),
      ],
    );
  }
}
