import 'dart:math';

import '../audio/audio_sequence.dart';

/// Слуховые интервалы PR-03. Числа полутонов — единственный источник для м3, б3 и ч5.
class IntervalEar {
  const IntervalEar._();

  static const semitones = {'м3': 3, 'б3': 4, 'ч5': 7};

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

/// Стадии 1–3 открыты параллельно уровню 2 и не ждут уроки L05.
bool isEarlyIntervalStage(int stage) => stage >= 1 && stage <= 3;
