import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class TemplateResult {
  const TemplateResult({required this.correct, required this.credit, required this.feedback});

  final bool correct;
  final double credit;
  final String feedback;
}

/// T03 — несколько верных ответов и частичный зачёт.
class MultiChoiceTemplate extends StatefulWidget {
  const MultiChoiceTemplate({
    super.key,
    required this.prompt,
    required this.options,
    required this.correctIndexes,
    required this.onResult,
  });

  final String prompt;
  final List<String> options;
  final Set<int> correctIndexes;
  final ValueChanged<TemplateResult> onResult;

  @override
  State<MultiChoiceTemplate> createState() => _MultiChoiceTemplateState();
}

class _MultiChoiceTemplateState extends State<MultiChoiceTemplate> {
  final _selected = <int>{};
  TemplateResult? _result;

  void _submit() {
    final hits = _selected.intersection(widget.correctIndexes).length;
    final misses = _selected.difference(widget.correctIndexes).length;
    final credit = widget.correctIndexes.isEmpty ? 0.0 : (hits / widget.correctIndexes.length) * (misses == 0 ? 1 : 0.5);
    final correct = hits == widget.correctIndexes.length && misses == 0;
    final result = TemplateResult(
      correct: correct,
      credit: correct ? 1 : credit,
      feedback: correct ? 'Верно' : 'Частично',
    );
    setState(() => _result = result);
    widget.onResult(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.prompt),
        for (var i = 0; i < widget.options.length; i++)
          CheckboxListTile(
            value: _selected.contains(i),
            title: Text(widget.options[i]),
            onChanged: _result == null
                ? (value) => setState(() {
                      if (value ?? false) {
                        _selected.add(i);
                      } else {
                        _selected.remove(i);
                      }
                    })
                : null,
          ),
        FilledButton(onPressed: _result == null ? _submit : null, child: const Text('Проверить')),
        if (_result != null) Text(_result!.feedback),
      ],
    );
  }
}

/// T04 — собрать порядок нажатиями.
class OrderTemplate extends StatefulWidget {
  const OrderTemplate({
    super.key,
    required this.prompt,
    required this.items,
    required this.correctOrder,
    required this.onResult,
  });

  final String prompt;
  final List<String> items;
  final List<String> correctOrder;
  final ValueChanged<TemplateResult> onResult;

  @override
  State<OrderTemplate> createState() => _OrderTemplateState();
}

class _OrderTemplateState extends State<OrderTemplate> {
  final _placed = <String>[];
  TemplateResult? _result;

  void _add(String item) {
    if (_result != null || _placed.contains(item)) return;
    TemplateResult? result;
    setState(() {
      _placed.add(item);
      if (_placed.length < widget.correctOrder.length) return;
      final correct = _placed.join() == widget.correctOrder.join();
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
        Text(_placed.join(' ')),
        for (final item in widget.items)
          OutlinedButton(onPressed: () => _add(item), child: Text(item)),
        if (_result != null) Text(_result!.feedback),
      ],
    );
  }
}

/// T06 — клавиатура на 1–2 октавы. Чёрные клавиши выше белых.
class KeyboardTemplate extends StatelessWidget {
  const KeyboardTemplate({
    super.key,
    required this.prompt,
    required this.whiteNotes,
    required this.blackNotes,
    required this.correctMidi,
    required this.onResult,
  });

  final String prompt;
  final List<({String label, int midi})> whiteNotes;
  final List<({String label, int midi})> blackNotes;
  final int correctMidi;
  final ValueChanged<TemplateResult> onResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(prompt),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: Row(
            children: [
              for (final note in blackNotes)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.darkCard,
                        minimumSize: const Size(48, 44),
                      ),
                      onPressed: () => _answer(note.midi),
                      child: Text(note.label),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final note in whiteNotes)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: OutlinedButton(
                    onPressed: () => _answer(note.midi),
                    child: Text(note.label),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _answer(int midi) {
    final correct = midi == correctMidi;
    onResult(TemplateResult(correct: correct, credit: correct ? 1 : 0, feedback: correct ? 'Верно' : 'Пока не то'));
  }
}

/// T11 — пары: сначала левая карточка, затем правая.
class MatchPairsTemplate extends StatefulWidget {
  const MatchPairsTemplate({
    super.key,
    required this.prompt,
    required this.left,
    required this.right,
    required this.pairs,
    required this.onResult,
  });

  final String prompt;
  final List<String> left;
  final List<String> right;
  final Map<String, String> pairs;
  final ValueChanged<TemplateResult> onResult;

  @override
  State<MatchPairsTemplate> createState() => _MatchPairsTemplateState();
}

class _MatchPairsTemplateState extends State<MatchPairsTemplate> {
  String? _pending;
  var _hits = 0;
  String? _feedback;

  void _tapLeft(String item) {
    if (_feedback != null) return;
    setState(() => _pending = item);
  }

  void _tapRight(String item) {
    final pending = _pending;
    if (pending == null || _feedback != null) return;
    if (widget.pairs[pending] == item) {
      _hits += 1;
      _pending = null;
      if (_hits == widget.pairs.length) {
        _feedback = 'Верно';
        widget.onResult(const TemplateResult(correct: true, credit: 1, feedback: 'Верно'));
      }
    } else {
      _feedback = 'Пока не то';
      widget.onResult(const TemplateResult(correct: false, credit: 0, feedback: 'Пока не то'));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.prompt),
        for (final item in widget.left)
          OutlinedButton(onPressed: () => _tapLeft(item), child: Text(item)),
        for (final item in widget.right)
          FilledButton(onPressed: () => _tapRight(item), child: Text(item)),
        if (_feedback != null) Text(_feedback!),
      ],
    );
  }
}
