import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import '../../curriculum/models/practice_set.dart';
import '../audio/audio_sequence.dart';
import '../audio/practice_audio_player.dart';
import '../progress/clock.dart';
import '../progress/practice_attempt.dart';
import '../progress/progress_store.dart';
import '../trainers/degree_dictation.dart';
import '../trainers/interval_ear.dart';
import '../trainers/stage_catalog.dart';
import '../widgets/sound_replay_button.dart';

/// Сессия одной стадии: число заданий, порог и скрытие нот берутся из каталога.
class StageRunScreen extends StatefulWidget {
  const StageRunScreen({
    super.key,
    required this.set,
    required this.stage,
    required this.player,
    required this.catalog,
    required this.clock,
    required this.seed,
    this.progress,
  });

  final PracticeSet set;
  final int stage;
  final PracticeAudioPlayer player;
  final CurriculumCatalog catalog;
  final ProgressStore? progress;
  final Clock clock;
  final int seed;

  @override
  State<StageRunScreen> createState() => _StageRunScreenState();
}

class _StageRunScreenState extends State<StageRunScreen> {
  late StageSessionPlan _plan;
  late int _seed;
  late DateTime _started;
  var _index = 0;
  var _correct = 0;
  var _wrongs = 0;
  var _replays = SoundReplayButton.freeReplays;
  var _finished = false;
  String? _feedback;
  String? _detail;
  int? _wrongBar;
  final _picks = <String>[];
  final _taps = <int>[];

  StageTask get _task => _plan.tasks[_index];

  @override
  void initState() {
    super.initState();
    _seed = widget.seed;
    _plan = buildStageSession(set: widget.set, stage: widget.stage, seed: _seed);
    _started = widget.clock.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _play() {
    final audio = _task.audio;
    if (audio == null) return;
    widget.player.play(audio);
  }

  void _replay() {
    if (_replays <= 0 || _feedback != null) return;
    setState(() => _replays -= 1);
    _play();
  }

  void _grade(String value) {
    if (_feedback != null || _finished) return;
    final ok = value == _task.answer;
    if (ok) _correct += 1;
    final store = widget.progress;
    if (store != null) {
      recordPracticeAnswer(
        store: store,
        catalog: widget.catalog,
        setId: widget.set.id,
        correct: ok,
        tonality: _task.tonality,
      );
    }
    if (!ok) {
      _wrongs += 1;
      if (_wrongs >= 2) _compare(_task, value);
    }
    setState(() {
      _feedback = ok ? 'Верно' : 'Пока не то';
      _detail = ok ? _plan.correctFeedback : _plan.errorFeedback;
      _wrongBar = ok || !_task.namesBars ? null : wrongBarOf(value, _task.answer);
    });
  }

  void _compare(StageTask task, String chosen) {
    final correctSteps = IntervalEar.semitones[task.answer];
    final chosenSteps = IntervalEar.semitones[chosen];
    final bass = task.bassMidi;
    if (correctSteps != null && chosenSteps != null && bass != null) {
      widget.player.play(intervalComparison(
        bassMidi: bass,
        correctSemitones: correctSteps,
        chosenSemitones: chosenSteps,
      ));
      return;
    }
    final correctDegree = int.tryParse(task.answer);
    final chosenDegree = int.tryParse(chosen);
    if (correctDegree == null ||
        chosenDegree == null ||
        correctDegree < 1 ||
        correctDegree > 7 ||
        chosenDegree < 1 ||
        chosenDegree > 7 ||
        task.soundedMidi.isEmpty ||
        !DegreeDictation.needsComparison(correctDegree, chosenDegree)) {
      return;
    }
    final shift = DegreeDictation.semitones[chosenDegree - 1] -
        DegreeDictation.semitones[correctDegree - 1];
    widget.player.play(TonalPrompt.comparative(
      correctMidi: task.soundedMidi.last,
      chosenMidi: task.soundedMidi.last + shift,
    ));
  }

  void _tile(String tile) {
    if (_feedback != null) return;
    _picks.add(tile);
    if (_picks.length >= _task.sequenceLength) {
      _grade(_picks.join(' '));
      return;
    }
    setState(() {});
  }

  void _tapBeat() {
    if (_feedback != null) return;
    _taps.add(widget.clock.now().difference(_started).inMilliseconds);
    if (_taps.length < _task.beats) {
      setState(() {});
      return;
    }
    final ok = tapsMatchGrid(
      _taps,
      beats: _task.beats,
      gapMs: _task.gapMs,
      toleranceMs: _task.toleranceMs,
    );
    _grade(ok ? _task.answer : 'мимо');
  }

  void _advance() {
    if (_index + 1 >= _plan.tasks.length) {
      final passed = _plan.passed(_correct);
      if (passed) widget.progress?.markStagePassed(widget.set.id, widget.stage);
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index += 1;
      _feedback = null;
      _detail = null;
      _wrongBar = null;
      _picks.clear();
      _taps.clear();
      _replays = SoundReplayButton.freeReplays;
      _started = widget.clock.now();
    });
    _play();
  }

  void _retry() {
    setState(() {
      _seed += 1;
      _plan = buildStageSession(set: widget.set, stage: widget.stage, seed: _seed);
      _index = 0;
      _correct = 0;
      _wrongs = 0;
      _finished = false;
      _feedback = null;
      _detail = null;
      _wrongBar = null;
      _picks.clear();
      _taps.clear();
      _replays = SoundReplayButton.freeReplays;
      _started = widget.clock.now();
    });
    _play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_plan.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _finished ? _summary() : _taskBody(),
      ),
    );
  }

  Widget _summary() {
    final passed = _plan.passed(_correct);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(passed ? 'Сдано' : 'Пока не сдано',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text('$_correct из ${_plan.tasks.length}'),
        const SizedBox(height: 24),
        if (!passed)
          FilledButton(onPressed: _retry, child: const Text('Ещё раз')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('К этапам'),
        ),
      ],
    );
  }

  Widget _taskBody() {
    final task = _task;
    return ListView(
      children: [
        Text('Задание ${_index + 1} из ${_plan.tasks.length}'),
        const SizedBox(height: 12),
        if (task.audio != null)
          SoundReplayButton(remaining: _replays, onPressed: _replay),
        const SizedBox(height: 12),
        if (!task.showNotation) const Text('Ноты скрыты'),
        if (task.showNotation && task.visible != null) Text(task.visible!),
        const SizedBox(height: 12),
        Text(task.prompt),
        const SizedBox(height: 16),
        if (task.input == StageInput.choice)
          for (final choice in task.choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton(
                onPressed: _feedback == null ? () => _grade(choice) : null,
                child: Text(choice),
              ),
            ),
        if (task.input == StageInput.sequence) ...[
          if (_picks.isNotEmpty) Text('Выбрано: ${_picks.join(' ')}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tile in task.tiles)
                FilledButton(
                  onPressed: _feedback == null ? () => _tile(tile) : null,
                  child: Text(tile),
                ),
            ],
          ),
          if (_picks.isNotEmpty && _feedback == null)
            TextButton(
              onPressed: () => setState(_picks.clear),
              child: const Text('Стереть'),
            ),
        ],
        if (task.input == StageInput.tap)
          FilledButton(
            onPressed: _feedback == null ? _tapBeat : null,
            child: Text('Доля (${_taps.length} из ${task.beats})'),
          ),
        if (_feedback != null) ...[
          const SizedBox(height: 16),
          Text(_feedback!),
          if (_detail != null) Text(_detail!),
          if (_wrongBar != null) Text('Неверный такт $_wrongBar'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _advance,
            child: Text(_index + 1 == _plan.tasks.length ? 'Итог' : 'Дальше'),
          ),
        ],
      ],
    );
  }
}
