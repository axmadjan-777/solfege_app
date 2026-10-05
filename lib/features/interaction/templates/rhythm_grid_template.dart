import 'package:flutter/material.dart';

import 'level01_templates.dart';

/// T08 — ритмическая сетка. Сюда же ведёт фолбэк калибровки вместе с T02.
class RhythmGridTemplate extends StatefulWidget {
  const RhythmGridTemplate({
    super.key,
    required this.prompt,
    required this.beats,
    required this.palette,
    required this.expected,
    required this.onResult,
  });

  final String prompt;
  final int beats;
  final List<String> palette;
  final List<String> expected;
  final ValueChanged<TemplateResult> onResult;

  @override
  State<RhythmGridTemplate> createState() => _RhythmGridTemplateState();
}

class _RhythmGridTemplateState extends State<RhythmGridTemplate> {
  final _placed = <String>[];
  TemplateResult? _result;

  void _add(String value) {
    if (_result != null || _placed.length >= widget.beats) return;
    TemplateResult? result;
    setState(() {
      _placed.add(value);
      if (_placed.length < widget.beats) return;
      final correct = _placed.join('|') == widget.expected.join('|');
      result = TemplateResult(correct: correct, credit: correct ? 1 : 0, feedback: correct ? 'Верно' : 'Пока не то');
      _result = result;
    });
    if (result != null) widget.onResult(result!);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.prompt),
        const SizedBox(height: 8),
        Text(_placed.isEmpty ? 'Пустой такт' : _placed.join(' ')),
        const SizedBox(height: 8),
        for (final item in widget.palette)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(onPressed: () => _add(item), child: Text(item)),
          ),
        if (_result != null) Text(_result!.feedback),
      ],
    );
  }
}
