import 'interval_ear.dart';

/// Вверх: от нижнего звука прибавляются полутоны интервала.
int noteAbove(int bassMidi, String label) => bassMidi + IntervalEar.semitones[label]!;

/// Вниз: результат ниже стартового звука. Качество считается от нового нижнего звука.
int noteBelow(int topMidi, String label) => topMidi - IntervalEar.semitones[label]!;

bool placedUpward(int startMidi, int resultMidi) => resultMidi > startMidi;

/// Число интервала: секунда 2, терция 3, … септима 7.
int intervalNumber(String label) {
  const numbers = {
    'м2': 2,
    'б2': 2,
    'м3': 3,
    'б3': 3,
    'ч4': 4,
    'тритон': 5,
    'ч5': 5,
    'м6': 6,
    'б6': 6,
    'м7': 7,
    'б7': 7,
  };
  return numbers[label]!;
}

String invertedLabel(String label) => IntervalEar.labelFor(IntervalEar.inversion(IntervalEar.semitones[label]!))!;

bool inversionRule(String label) {
  final inverted = invertedLabel(label);
  return intervalNumber(label) + intervalNumber(inverted) == 9;
}

/// Стадии 3–5 ждут ту же компетенцию счёта, что и стадии 1–2.
bool pr04BuildStageOpen(int stage, {required bool countMastered}) {
  if (stage < 1 || stage > 5) return false;
  return countMastered;
}
