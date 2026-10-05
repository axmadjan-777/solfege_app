import 'package:flutter/material.dart';

import 'level01_templates.dart';

/// T09 — тап по пульсу. Нужен уроку L00-06.
class TapPulseTemplate extends StatefulWidget {
  const TapPulseTemplate({
    super.key,
    required this.prompt,
    required this.tapsRequired,
    required this.onResult,
  });

  final String prompt;
  final int tapsRequired;
  final ValueChanged<TemplateResult> onResult;

  @override
  State<TapPulseTemplate> createState() => _TapPulseTemplateState();
}

class _TapPulseTemplateState extends State<TapPulseTemplate> {
  var _taps = 0;
  TemplateResult? _result;

  void _tap() {
    if (_result != null) return;
    _taps += 1;
    if (_taps < widget.tapsRequired) {
      setState(() {});
      return;
    }
    const result = TemplateResult(correct: true, credit: 1, feedback: 'Верно');
    setState(() => _result = result);
    widget.onResult(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.prompt),
        const SizedBox(height: 12),
        FilledButton(onPressed: _tap, child: Text('Тап $_taps/${widget.tapsRequired}')),
        if (_result != null) Text(_result!.feedback),
      ],
    );
  }
}
