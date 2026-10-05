import 'dart:math';

import '../../curriculum/models/practice_set.dart';
import '../audio/audio_sequence.dart';
import 'degree_dictation.dart';
import 'interval_count.dart';
import 'interval_ear.dart';
import 'note_reading.dart';
import 'rhythm_dictation.dart';
import 'rhythm_trainer.dart';
import 'scale_ear.dart';
import 'sight_reading.dart';
import 'triad_formulas.dart';

enum StageAccess { open, locked, soon }

enum StageInput { choice, sequence, tap }

class StageOffer {
  const StageOffer({
    required this.stage,
    required this.title,
    required this.access,
  });

  final int stage;
  final String title;
  final StageAccess access;
}

class StageTask {
  const StageTask({
    required this.prompt,
    required this.answer,
    required this.input,
    this.choices = const [],
    this.tiles = const [],
    this.sequenceLength = 0,
    this.audio,
    this.showNotation = false,
    this.visible,
    this.beats = 0,
    this.gapMs = 0,
    this.toleranceMs = 0,
    this.tonality = 'C',
    this.soundedMidi = const [],
    this.bassMidi,
    this.namesBars = false,
  });

  final String prompt;
  final String answer;
  final StageInput input;
  final List<String> choices;
  final List<String> tiles;
  final int sequenceLength;
  final AudioSequence? audio;
  final bool showNotation;
  final String? visible;
  final int beats;
  final int gapMs;
  final int toleranceMs;
  final String tonality;
  final List<int> soundedMidi;
  final int? bassMidi;
  final bool namesBars;

  bool get answerable {
    return switch (input) {
      StageInput.choice => choices.contains(answer),
      StageInput.sequence =>
        answer.split(' ').length == sequenceLength &&
            answer.split(' ').every(tiles.contains),
      StageInput.tap => beats > 0 && gapMs > 0 && toleranceMs > 0,
    };
  }
}

class StageSessionPlan {
  const StageSessionPlan({
    required this.setId,
    required this.stage,
    required this.title,
    required this.tasks,
    required this.minAccuracy,
    required this.minItems,
    required this.correctFeedback,
    required this.errorFeedback,
  });

  final String setId;
  final int stage;
  final String title;
  final List<StageTask> tasks;
  final double minAccuracy;
  final int minItems;
  final String correctFeedback;
  final String errorFeedback;

  bool passed(int correct) {
    return DegreeDictation.passed(
      correct: correct,
      total: tasks.length,
      minAccuracy: minAccuracy,
      minItems: minItems,
    );
  }
}

int stageSessionSeed(String setId, int stage, int attemptCount) {
  return Object.hash(setId, stage, attemptCount);
}

/// Не-MVP стадия — «Скоро». Следующая MVP-стадия ждёт сдачи предыдущей.
/// У PR-07 стадия 3 вне MVP, поэтому стадия 4 открывается после стадии 2.
List<StageOffer> stageOffers(PracticeSet set, Set<int> passed) {
  final offers = <StageOffer>[];
  int? previousMvp;
  for (final stage in set.stages) {
    if (!stage.mvpStatus.isMvp) {
      offers.add(StageOffer(
        stage: stage.stage,
        title: stage.title,
        access: StageAccess.soon,
      ));
      continue;
    }
    final open = previousMvp == null || passed.contains(previousMvp);
    offers.add(StageOffer(
      stage: stage.stage,
      title: stage.title,
      access: open ? StageAccess.open : StageAccess.locked,
    ));
    previousMvp = stage.stage;
  }
  return offers;
}

StageSessionPlan buildStageSession({
  required PracticeSet set,
  required int stage,
  required int seed,
}) {
  final spec = set.stages.firstWhere((item) => item.stage == stage);
  if (!spec.mvpStatus.isMvp) {
    throw StateError('${set.id} стадия $stage вне MVP');
  }
  final random = Random(seed);
  final tasks = switch (set.id) {
    'PR-01' => _degrees(spec, random),
    'PR-03' => _intervals(spec, random),
    'PR-04' => _intervalCount(spec, random),
    'PR-05' => _scales(spec, random),
    'PR-06' => _chordEar(spec, random),
    'PR-07' => _triads(spec, random),
    'PR-08' => _notes(spec, random),
    'PR-09' => _rhythm(spec, random),
    'PR-10' => _dictation(spec, random),
    'PR-13' => _sight(spec, random),
    _ => throw StateError('${set.id} не входит в прогон стадий MVP'),
  };
  final count = _count(spec);
  if (tasks.length != count) {
    throw StateError('${set.id} стадия $stage: ${tasks.length} вместо $count');
  }
  return StageSessionPlan(
    setId: set.id,
    stage: stage,
    title: spec.title,
    tasks: tasks,
    minAccuracy: (spec.pass['min_accuracy'] as num).toDouble(),
    minItems: (spec.pass['min_items'] as num).toInt(),
    correctFeedback: spec.feedback['correct'] as String? ?? 'Верно',
    errorFeedback: spec.feedback['first_error'] as String? ?? 'Пока не то',
  );
}

bool tapsMatchGrid(
  List<int> elapsedMs, {
  required int beats,
  required int gapMs,
  required int toleranceMs,
}) {
  if (elapsedMs.length != beats) return false;
  for (var i = 0; i < beats; i++) {
    final hit = OnsetJudge.hit(
      tapMs: elapsedMs[i],
      clickMs: gapMs * (i + 1),
      latencyOffsetMs: 0,
      toleranceMs: toleranceMs,
    );
    if (!hit) return false;
  }
  return true;
}

/// Слова ритма, включая «четвертная пауза» как один знак.
List<String> splitRhythmBar(String bar) {
  const compounds = ['четвертная пауза', 'половинная пауза'];
  final parts = bar.split(' ');
  final words = <String>[];
  var index = 0;
  while (index < parts.length) {
    final pair = index + 1 < parts.length ? '${parts[index]} ${parts[index + 1]}' : '';
    if (compounds.contains(pair)) {
      words.add(pair);
      index += 2;
      continue;
    }
    if (parts[index].isNotEmpty) words.add(parts[index]);
    index += 1;
  }
  return words;
}

/// Номер первого такта, которым выбранный рисунок отличается от верного.
int? wrongBarOf(String chosen, String answer) {
  final expected = answer.split(' / ');
  final actual = chosen.split(' / ');
  if (expected.length != actual.length) return 1;
  for (var i = 0; i < expected.length; i++) {
    if (expected[i] != actual[i]) return i + 1;
  }
  return null;
}

const _syllables = ['до', 'ре', 'ми', 'фа', 'соль', 'ля', 'си'];

String _degreeName(int degree) => degree == 8 ? 'до' : _syllables[degree - 1];
const _chromatic = [
  'до',
  'до-диез',
  'ре',
  'ре-диез',
  'ми',
  'фа',
  'фа-диез',
  'соль',
  'соль-диез',
  'ля',
  'ля-диез',
  'си',
];

int _count(PracticeStage stage) {
  final asked = _n(stage.params, 'items_per_session', 8);
  final minimum = (stage.pass['min_items'] as num?)?.toInt() ?? asked;
  return asked > minimum ? asked : minimum;
}

int _n(Map<String, dynamic> params, String key, int fallback) {
  final value = params[key];
  return value is num ? value.toInt() : fallback;
}

int _low(PracticeStage stage, int fallback) =>
    _n(stage.params, 'midi_low', fallback);

int _high(PracticeStage stage, int fallback) =>
    _n(stage.params, 'midi_high', fallback);

List<String> _strs(Map<String, dynamic> params, String key) {
  final raw = params[key];
  if (raw is! List) return const [];
  return [for (final value in raw) '$value'];
}

List<int> _coverageInts(PracticeStage stage) {
  final raw = stage.pass['coverage'];
  if (raw is! List) return const [];
  return [for (final value in raw) if (value is num) value.toInt()];
}

List<String> _coverageKeys(PracticeStage stage) {
  final raw = stage.pass['coverage'];
  if (raw is! List) return const [];
  return [for (final value in raw) if (value is String) value];
}

AudioSequence _cadence(List<NoteEvent> notes) {
  return AudioSequence([
    const ChordEvent(TonalPrompt.cadenceI),
    const ChordEvent(TonalPrompt.cadenceIV),
    const ChordEvent(TonalPrompt.cadenceV),
    const ChordEvent(TonalPrompt.cadenceI),
    const RestEvent(500),
    ...notes,
  ]);
}

int _tonicOf(String key) {
  return switch (key) {
    'G' => 67,
    'F' => 65,
    'D' => 62,
    'Bb' => 70,
    'A' => 69,
    'Am' => 69,
    'Em' => 64,
    'Dm' => 62,
    _ => 60,
  };
}

String _keyName(String key) {
  return switch (key) {
    'G' => 'соль',
    'F' => 'фа',
    'D' => 'ре',
    'Bb' => 'си-бемоль',
    'A' => 'ля',
    'Am' => 'ля минор',
    'Em' => 'ми минор',
    'Dm' => 'ре минор',
    _ => 'до',
  };
}

List<int> _fillInts(List<int> targets, int count, Random random, List<int> required) {
  final items = <int>[];
  for (final degree in required) {
    if (targets.contains(degree) && items.length < count) items.add(degree);
  }
  while (items.length < count) {
    items.add(targets[random.nextInt(targets.length)]);
  }
  items.shuffle(random);
  return items;
}

List<StageTask> _degrees(PracticeStage stage, Random random) {
  final targets = stage.targetSet;
  final count = _count(stage);
  final low = _low(stage, 60);
  final high = _high(stage, 72);
  final length = _n(stage.params, 'sequence_length', 1);
  final format = stage.params['answer_format'] as String? ?? '';
  final home = format == 'single_choice_2' && stage.stage == 1;
  final sequence = format.startsWith('sequence');
  final keys = _strs(stage.params, 'keys');
  final neededKeys = _coverageKeys(stage);
  final degrees = stage.stage == 8
      ? <int>[1, 1, 1, ..._fillInts(targets, count - 3, random, _coverageInts(stage))]
      : _fillInts(
          targets,
          sequence ? count * length : count,
          random,
          _coverageInts(stage),
        );
  final tasks = <StageTask>[];
  var cursor = 0;
  int? register;
  var streak = 0;
  for (var index = 0; index < count; index++) {
    final key = _keyAt(keys, neededKeys, index);
    final tonic = _tonicOf(key);
    final slice = sequence
        ? degrees.sublist(cursor, cursor + length)
        : <int>[degrees[index]];
    cursor += slice.length;
    final midis = <int>[];
    for (final degree in slice) {
      final avoid = stage.stage == 8 && streak >= 2 ? register : null;
      final midi = DegreeDictation.pickMidi(
        tonicMidi: tonic,
        degree: degree,
        low: low,
        high: high,
        avoidRegister: avoid,
      );
      final next = AbsolutePitchGuard.registerOf(midi);
      if (next == register) {
        streak += 1;
      } else {
        register = next;
        streak = 1;
      }
      midis.add(midi);
    }
    final tempo = _tempo(stage, random);
    final durations = _strs(stage.params, 'durations');
    final notes = <NoteEvent>[];
    if (durations.isEmpty) {
      notes.addAll([for (final midi in midis) NoteEvent(midi)]);
    } else {
      final bar = _fitBar(random, durations, 4);
      for (var i = 0; i < midis.length; i++) {
        notes.add(NoteEvent(midis[i], durationMs: _durationMs(bar[i % bar.length], tempo)));
      }
    }
    if (home) {
      final arrived = slice.single == 1;
      tasks.add(StageTask(
        prompt: 'Фраза закончилась?',
        answer: arrived ? 'вернулось домой' : 'висит в воздухе',
        input: StageInput.choice,
        choices: const ['вернулось домой', 'висит в воздухе'],
        audio: _cadence(notes),
        showNotation: false,
        tonality: key,
        soundedMidi: midis,
      ));
      continue;
    }
    if (sequence) {
      tasks.add(StageTask(
        prompt: 'Какие ступени прозвучали?',
        answer: slice.join(' '),
        input: StageInput.sequence,
        tiles: [for (final degree in targets) '$degree'],
        sequenceLength: length,
        audio: _cadence(notes),
        showNotation: false,
        tonality: key,
        soundedMidi: midis,
      ));
      continue;
    }
    final named = key == 'C' ? '' : 'Тональность: ${_keyName(key)}. ';
    tasks.add(StageTask(
      prompt: '$namedКакая ступень?',
      answer: '${slice.single}',
      input: StageInput.choice,
      choices: [for (final degree in targets) '$degree'],
      audio: _cadence(notes),
      showNotation: false,
      tonality: key,
      soundedMidi: midis,
    ));
  }
  return tasks;
}

String _keyAt(List<String> keys, List<String> needed, int index) {
  if (keys.isEmpty) return 'C';
  final order = <String>[...needed.where(keys.contains), ...keys.where((key) => !needed.contains(key))];
  return order[(index ~/ 2) % order.length];
}

int _tempo(PracticeStage stage, Random random) {
  final raw = stage.params['tempo_bpm'];
  final values = raw is List
      ? [for (final value in raw) if (value is num) value.toInt()]
      : const <int>[];
  final bpm = values.isEmpty ? 80 : values[random.nextInt(values.length)];
  return OnsetJudge.cappedTempo(AbsolutePitchGuard.introRhythmBpm(bpm));
}

int _durationMs(String token, int bpm) {
  final quarter = (60000 / bpm).round();
  return switch (token) {
    'e' => quarter ~/ 2,
    'h' => quarter * 2,
    'w' => quarter * 4,
    _ => quarter,
  };
}

List<StageTask> _intervals(PracticeStage stage, Random random) {
  final count = _count(stage);
  final low = _low(stage, 48);
  final high = _high(stage, 72);
  final format = stage.params['answer_format'] as String? ?? '';
  if (stage.stage == 1 || format == 'single_choice_2' && stage.stage == 1) {
    return _wider(count, low, high, random);
  }
  final labels = switch (stage.stage) {
    2 => const ['м3', 'б3'],
    3 => const ['м3', 'б3', 'ч5'],
    _ => IntervalEar.stageLabels[stage.stage] ?? const ['м3', 'б3'],
  };
  final seen = <String>{};
  return [
    for (var i = 0; i < count; i++)
      _intervalTask(labels, low, high, random, seen),
  ];
}

List<StageTask> _wider(int count, int low, int high, Random random) {
  const pool = [3, 4, 5, 7];
  final tasks = <StageTask>[];
  final seen = <String>{};
  for (var i = 0; i < count; i++) {
    final bass = low + random.nextInt(high - low - 7);
    var first = pool[random.nextInt(pool.length)];
    var second = pool[random.nextInt(pool.length)];
    var guard = 0;
    while ((second == first || !seen.add('$bass:$first:$second')) && guard < 20) {
      first = pool[random.nextInt(pool.length)];
      second = pool[random.nextInt(pool.length)];
      guard += 1;
    }
    if (first == second) second = first == 7 ? 3 : 7;
    final answer = second > first ? 'второй шире' : 'первый шире';
    tasks.add(StageTask(
      prompt: 'Какой интервал шире?',
      answer: answer,
      input: StageInput.choice,
      choices: const ['первый шире', 'второй шире'],
      audio: AudioSequence([
        NoteEvent(bass),
        NoteEvent(bass + first),
        const RestEvent(300),
        NoteEvent(bass),
        NoteEvent(bass + second),
      ]),
      showNotation: false,
      soundedMidi: [bass, bass + first, bass, bass + second],
      bassMidi: bass,
    ));
  }
  return tasks;
}

StageTask _intervalTask(
  List<String> labels,
  int low,
  int high,
  Random random,
  Set<String> seen,
) {
  for (var attempt = 0; attempt < 80; attempt++) {
    final label = labels[random.nextInt(labels.length)];
    final steps = IntervalEar.semitones[label]!;
    final highest = high - steps;
    if (highest < low) continue;
    final bass = low + random.nextInt(highest - low + 1);
    if (!seen.add('$bass:$steps')) continue;
    return StageTask(
      prompt: 'Какой интервал?',
      answer: label,
      input: StageInput.choice,
      choices: labels,
      audio: intervalPlayback(bassMidi: bass, steps: steps, harmonic: false),
      showNotation: false,
      soundedMidi: [bass, bass + steps],
      bassMidi: bass,
    );
  }
  throw StateError('В диапазоне не осталось новых интервалов');
}

List<StageTask> _intervalCount(PracticeStage stage, Random random) {
  final count = _count(stage);
  if (stage.stage == 1) {
    final tasks = <StageTask>[];
    const pairs = [
      (1, 4),
      (1, 5),
      (2, 6),
      (3, 5),
      (1, 3),
      (4, 7),
      (2, 5),
      (5, 8),
    ];
    for (var i = 0; i < count; i++) {
      final pair = pairs[i % pairs.length];
      final span = degreeSpan(pair.$1, pair.$2);
      tasks.add(StageTask(
        prompt: 'Сколько ступеней между краями, включая оба?',
        answer: '$span',
        input: StageInput.choice,
        choices: const ['1', '2', '3', '4', '5', '6', '7', '8'],
        showNotation: true,
        visible: '${_degreeName(pair.$1)} — ${_degreeName(pair.$2)}',
      ));
    }
    return tasks;
  }
  return [
    for (var i = 0; i < count; i++) _builtInterval(random),
  ];
}

StageTask _builtInterval(Random random) {
  final fifth = random.nextBool();
  final upper = fifth ? 'соль' : 'ми';
  return StageTask(
    prompt: fifth ? 'Построй квинту вверх от до' : 'Построй терцию вверх от до',
    answer: upper,
    input: StageInput.sequence,
    tiles: _syllables,
    sequenceLength: 1,
    showNotation: false,
    soundedMidi: [fifth ? 67 : 64],
  );
}

List<StageTask> _scales(PracticeStage stage, Random random) {
  final count = _count(stage);
  if (stage.stage == 1) {
    return [
      for (var i = 0; i < count; i++)
        const StageTask(
          prompt: 'Собери мажорную гамму от до',
          answer: 'тон тон полутон тон тон тон полутон',
          input: StageInput.sequence,
          tiles: ['тон', 'полутон'],
          sequenceLength: 7,
          showNotation: false,
        ),
    ];
  }
  final keys = _strs(stage.params, 'keys');
  final pool = keys.isEmpty ? const ['C', 'Am'] : keys;
  return [
    for (var i = 0; i < count; i++) _scaleEar(pool[i % pool.length]),
  ];
}

StageTask _scaleEar(String key) {
  final minor = key.endsWith('m');
  return StageTask(
    prompt: 'Мажор или минор?',
    answer: minor ? 'минор' : 'мажор',
    input: StageInput.choice,
    choices: const ['мажор', 'минор'],
    audio: scaleHearingContext(major: !minor, tonic: _tonicOf(key)),
    showNotation: false,
    tonality: key,
    soundedMidi: [ _tonicOf(key) ],
  );
}

List<StageTask> _chordEar(PracticeStage stage, Random random) {
  final count = _count(stage);
  final names = switch (stage.stage) {
    1 => const ['major', 'minor'],
    2 => const ['major', 'minor', 'dim'],
    _ => const ['major', 'minor', 'dim', 'aug'],
  };
  const title = {
    'major': 'большое',
    'minor': 'малое',
    'dim': 'уменьшённое',
    'aug': 'увеличенное',
  };
  return [
    for (var i = 0; i < count; i++)
      _oneChord(names[random.nextInt(names.length)], title, [for (final name in names) title[name]!]),
  ];
}

StageTask _oneChord(String name, Map<String, String> title, List<String> choices) {
  final formula = TriadFormulas.byName[name]!;
  return StageTask(
    prompt: 'Какое трезвучие?',
    answer: title[name]!,
    input: StageInput.choice,
    choices: choices,
    audio: AudioSequence([
      ChordEvent([for (final step in formula) 60 + step]),
    ]),
    showNotation: false,
    soundedMidi: [for (final step in formula) 60 + step],
  );
}

List<StageTask> _triads(PracticeStage stage, Random random) {
  final count = _count(stage);
  if (stage.stage == 4) {
    return [
      for (var i = 0; i < count; i++)
        StageTask(
          prompt: 'В большом трезвучии ошибка. Что поправить?',
          answer: i.isEven ? 'терцию' : 'квинту',
          input: StageInput.choice,
          choices: const ['терцию', 'квинту'],
          showNotation: true,
          visible: i.isEven ? 'до ре-диез соль' : 'до ми соль-диез',
          soundedMidi: i.isEven ? const [60, 63, 67] : const [60, 64, 68],
        ),
    ];
  }
  final kinds = stage.stage == 1
      ? const ['major']
      : const ['major', 'minor', 'dim', 'aug'];
  const spoken = {
    'major': 'большое',
    'minor': 'малое',
    'dim': 'уменьшённое',
    'aug': 'увеличенное',
  };
  return [
    for (var i = 0; i < count; i++)
      _spellTriad(kinds[i % kinds.length], spoken),
  ];
}

StageTask _spellTriad(String name, Map<String, String> spoken) {
  final formula = TriadFormulas.byName[name]!;
  final spelling = [for (final step in formula) _chromatic[step]].join(' ');
  return StageTask(
    prompt: 'Построй ${spoken[name]} трезвучие от до',
    answer: spelling,
    input: StageInput.sequence,
    tiles: _chromatic,
    sequenceLength: 3,
    showNotation: false,
    soundedMidi: [for (final step in formula) 60 + step],
  );
}

List<StageTask> _notes(PracticeStage stage, Random random) {
  final count = _count(stage);
  final pool = switch (stage.stage) {
    1 => const [60, 62, 64, 65, 67],
    4 => const [48, 50, 52, 53, 55, 57, 59, 60],
    5 => const [48, 53, 60, 64, 67, 72, 79],
    _ => const [57, 60, 64, 67, 71, 74, 79],
  };
  final choices = stage.stage == 1
      ? const ['до', 'ре', 'ми', 'фа', 'соль']
      : _syllables;
  final bass = stage.stage == 4 || stage.stage == 5;
  return [
    for (var i = 0; i < count; i++)
      _oneNote(pool[random.nextInt(pool.length)], choices, bass: bass && (stage.stage == 4 || i.isEven)),
  ];
}

StageTask _oneNote(int midi, List<String> choices, {required bool bass}) {
  final syllable = NoteReading.syllable(midi);
  final visible = bass
      ? 'Басовый ключ, шаг ${NoteReading.bassStepsFromF3(midi)}'
      : 'Скрипичный ключ, позиция ${NoteReading.trebleY(midi).toStringAsFixed(0)}';
  return StageTask(
    prompt: 'Как называется нота?',
    answer: syllable,
    input: StageInput.choice,
    choices: choices.contains(syllable) ? choices : [...choices, syllable],
    showNotation: true,
    visible: visible,
    soundedMidi: [midi],
  );
}

List<StageTask> _rhythm(PracticeStage stage, Random random) {
  final count = _count(stage);
  if (stage.stage == 2) {
    const meters = ['2', '3', '4'];
    return [
      for (var i = 0; i < count; i++)
        StageTask(
          prompt: 'Сколько долей в такте?',
          answer: meters[i % meters.length],
          input: StageInput.choice,
          choices: meters,
          audio: metronomeClicks(bpm: _tempo(stage, random), beats: int.parse(meters[i % meters.length])),
          showNotation: false,
        ),
    ];
  }
  final tolerance = _n(stage.params, 'tolerance_ms', OnsetJudge.toleranceMs(stage.stage));
  final beats = stage.stage == 1 ? 4 : 4;
  return [
    for (var i = 0; i < count; i++)
      _tapTask(stage, random, tolerance, beats),
  ];
}

StageTask _tapTask(PracticeStage stage, Random random, int tolerance, int beats) {
  final bpm = _tempo(stage, random);
  return StageTask(
    prompt: 'Тапни вместе с кликом',
    answer: 'доля',
    input: StageInput.tap,
    audio: metronomeClicks(bpm: bpm, beats: beats),
    showNotation: stage.showsNotation,
    beats: beats,
    gapMs: (60000 / bpm).round(),
    toleranceMs: tolerance,
  );
}

List<StageTask> _dictation(PracticeStage stage, Random random) {
  final count = _count(stage);
  final tokens = _strs(stage.params, 'durations');
  final bars = _n(stage.params, 'bars', 1);
  final meters = _strs(stage.params, 'meter');
  return [
    for (var i = 0; i < count; i++)
      _rhythmChoice(random, tokens, bars, meters.isEmpty ? '4/4' : meters[i % meters.length]),
  ];
}

StageTask _rhythmChoice(Random random, List<String> tokens, int bars, String meter) {
  final beats = meter.startsWith('3') ? 3 : 4;
  final patterns = <String>[];
  var guard = 0;
  while (patterns.length < 3 && guard < 40) {
    guard += 1;
    final namedBars = [
      for (var bar = 0; bar < bars; bar++)
        _fitBar(random, tokens, beats).map(_durationName).toList(),
    ];
    final fits = [
      for (final bar in namedBars)
        RhythmDictation.barFits(bar, beatsInBar: beats),
    ].every((ok) => ok);
    if (!fits) continue;
    final written = namedBars.map((bar) => bar.join(' ')).join(' / ');
    if (!patterns.contains(written)) patterns.add(written);
  }
  while (patterns.length < 3) {
    patterns.add(List.filled(beats, 'четверть').join(' '));
  }
  return StageTask(
    prompt: bars == 1 ? 'Какой ритм прозвучал?' : 'Какие такты прозвучали?',
    answer: patterns.first,
    input: StageInput.choice,
    choices: patterns,
    namesBars: true,
    beats: beats,
    showNotation: false,
    audio: metronomeClicks(bpm: 80, beats: beats),
  );
}

String _durationName(String token) {
  return switch (token) {
    'e' => 'восьмая',
    'h' => 'половинная',
    'w' => 'целая',
    'qr' => 'четвертная пауза',
    'hr' => 'половинная пауза',
    _ => 'четверть',
  };
}

List<String> _fitBar(Random random, List<String> tokens, num beats) {
  const size = {
    'q': 1.0,
    'e': 0.5,
    'h': 2.0,
    'w': 4.0,
    'qr': 1.0,
    'hr': 2.0,
  };
  final usable = [for (final token in tokens) if (size.containsKey(token)) token];
  if (usable.isEmpty) return List.filled(beats.toInt(), 'q');
  final chosen = <String>[];
  var left = beats.toDouble();
  var guard = 0;
  while (left > 0.001 && guard < 16) {
    guard += 1;
    final fit = [for (final token in usable) if (size[token]! <= left + 0.001) token];
    if (fit.isEmpty) break;
    final token = fit[random.nextInt(fit.length)];
    chosen.add(token);
    left -= size[token]!;
  }
  if (left > 0.001) return List.filled(beats.toInt(), 'q');
  return chosen;
}

List<StageTask> _sight(PracticeStage stage, Random random) {
  final count = _count(stage);
  final bpm = stage.stage == 2 ? _tempo(stage, random) : 0;
  return [
    for (var i = 0; i < count; i++) _phraseTask(random, bpm),
  ];
}

StageTask _phraseTask(Random random, int bpm) {
  final degrees = _allowedPhrase(random);
  final spelling = [for (final degree in degrees) _syllables[degree - 1]].join(' ');
  return StageTask(
    prompt: bpm == 0 ? 'Сыграй высоту фразы' : 'Сыграй фразу в ритме',
    answer: spelling,
    input: StageInput.sequence,
    tiles: _syllables,
    sequenceLength: degrees.length,
    showNotation: true,
    visible: spelling,
    gapMs: bpm == 0 ? 0 : (60000 / bpm).round(),
    soundedMidi: [for (final degree in degrees) 60 + DegreeDictation.semitones[degree - 1]],
  );
}

List<int> _allowedPhrase(Random random) {
  for (var attempt = 0; attempt < 40; attempt++) {
    final degrees = <int>[1];
    var spins = 0;
    while (degrees.length < 7 && spins < 24) {
      spins += 1;
      final from = degrees.last;
      final step = random.nextInt(5) - 2;
      var next = from + (step == 0 ? 1 : step);
      if (next < 1 || next > 7) next = from == 7 ? 6 : from + 1;
      if (SightPhrase([from, next]).hasTritoneLeap) continue;
      if (!SightPhrase([from, next]).leapsOnlyFromStable) continue;
      degrees.add(next);
    }
    if (degrees.length < 7) continue;
    degrees.add(1);
    final phrase = SightPhrase(degrees);
    if (phrase.isAllowed) return degrees;
  }
  return const [1, 2, 3, 2, 1, 2, 3, 1];
}
