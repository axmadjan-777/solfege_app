import 'dart:math';

import '../audio/audio_sequence.dart';

/// Слуховые интервалы PR-03. Число полутонов — единственный источник имени.
class IntervalEar {
  const IntervalEar._();

  static const semitones = {
    'м2': 1,
    'б2': 2,
    'м3': 3,
    'б3': 4,
    'ч4': 5,
    'тритон': 6,
    'ч5': 7,
    'м6': 8,
    'б6': 9,
    'м7': 10,
    'б7': 11,
  };

  static const stageLabels = {
    4: ['м3', 'б3', 'ч4', 'ч5'],
    5: ['м2', 'б2', 'м3', 'б3', 'м7', 'б7'],
    6: ['м6', 'б6', 'тритон', 'ч4', 'ч5', 'б2', 'м7', 'б7'],
    7: ['м2', 'б2', 'м3', 'б3', 'ч4', 'тритон', 'ч5', 'м6', 'б6', 'м7', 'б7'],
    8: ['м2', 'б2', 'м3', 'б3', 'ч4', 'тритон', 'ч5', 'м6', 'б6', 'м7', 'б7'],
  };

  static int? classify(int steps) {
    for (final entry in semitones.entries) {
      if (entry.value == steps) return entry.value;
    }
    return null;
  }

  static String? labelFor(int steps) {
    for (final entry in semitones.entries) {
      if (entry.value == steps) return entry.key;
    }
    return null;
  }

  /// Обращение внутри октавы: м2 ↔ б7, ч4 ↔ ч5, тритон остаётся тритоном.
  static int inversion(int steps) => 12 - steps;
}

class IntervalTask {
  const IntervalTask({required this.bassMidi, required this.semitones, required this.label});

  final int bassMidi;
  final int semitones;
  final String label;

  int get upperMidi => bassMidi + semitones;

  String get signature => '$bassMidi:$semitones';
}

class IntervalDrill {
  IntervalDrill({
    required int seed,
    required this.labels,
    this.midiLow = 48,
    this.midiHigh = 72,
  }) : _random = Random(seed);

  final Random _random;
  final List<String> labels;
  final int midiLow;
  final int midiHigh;
  final seen = <String>{};

  IntervalTask next() {
    for (var attempt = 0; attempt < 80; attempt++) {
      final label = labels[_random.nextInt(labels.length)];
      final steps = IntervalEar.semitones[label]!;
      final highestBass = midiHigh - steps;
      if (highestBass < midiLow) continue;
      final bass = midiLow + _random.nextInt(highestBass - midiLow + 1);
      final task = IntervalTask(bassMidi: bass, semitones: steps, label: label);
      if (!seen.add(task.signature)) continue;
      return task;
    }
    throw StateError('В диапазоне не осталось новых интервалов');
  }
}

/// Повторная ошибка м3/б3: верный интервал, ответ, верный интервал.
AudioSequence intervalComparison({
  required int bassMidi,
  required int correctSemitones,
  required int chosenSemitones,
}) {
  AudioSequence pair(int steps) => AudioSequence([
        NoteEvent(bassMidi),
        NoteEvent(bassMidi + steps),
      ]);
  return AudioSequence([
    ...pair(correctSemitones).events,
    ...pair(chosenSemitones).events,
    ...pair(correctSemitones).events,
  ]);
}

/// Стадии 1–3 открыты параллельно уровню 2. Стадии 4–8 ждут уроки интервалов.
bool isEarlyIntervalStage(int stage) => stage >= 1 && stage <= 3;

bool intervalStageOpen(int stage, {required bool intervalLessonsMastered}) {
  if (isEarlyIntervalStage(stage)) return true;
  if (stage >= 4 && stage <= 8) return intervalLessonsMastered;
  return false;
}

/// Гармонический интервал звучит вместе, мелодический — по очереди.
AudioSequence intervalPlayback({
  required int bassMidi,
  required int steps,
  required bool harmonic,
}) {
  if (harmonic) {
    return AudioSequence([
      ChordEvent([bassMidi, bassMidi + steps]),
    ]);
  }
  return AudioSequence([
    NoteEvent(bassMidi),
    NoteEvent(bassMidi + steps),
  ]);
}
