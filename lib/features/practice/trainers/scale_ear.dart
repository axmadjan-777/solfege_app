import '../audio/audio_sequence.dart';

/// «тон» = 2 полутона, «полутон» = 1. Мажор: полутоны только между III–IV и VII–I.
int stepSemitones(String name) {
  return switch (name) {
    'тон' => 2,
    'полутон' => 1,
    _ => throw ArgumentError.value(name, 'name', 'Ожидался тон или полутон'),
  };
}

List<int> formulaSemitones(List<String> steps) => [for (final step in steps) stepSemitones(step)];

bool isMajorFormula(List<String> steps) {
  if (steps.length != 7) return false;
  final sizes = formulaSemitones(steps);
  final sum = sizes.fold<int>(0, (total, size) => total + size);
  return sum == 12 && sizes[2] == 1 && sizes[6] == 1;
}

/// Терция: сумма первых двух шагов. 4 — мажор, 3 — минор.
bool isMajorByThird(List<int> steps) => steps[0] + steps[1] == 4;

/// Пять звуков вверх и тоническое трезвучие блоком.
AudioSequence scaleHearingContext({required bool major, int tonic = 60}) {
  final steps = major ? const [2, 2, 1, 2, 2, 2, 1] : const [2, 1, 2, 2, 1, 2, 2];
  final notes = <int>[tonic];
  var midi = tonic;
  for (var i = 0; i < 4; i++) {
    midi += steps[i];
    notes.add(midi);
  }
  final third = tonic + steps[0] + steps[1];
  return AudioSequence([
    for (final note in notes) NoteEvent(note),
    ChordEvent([tonic, third, tonic + 7]),
  ]);
}

bool pr05CanStart(bool Function(String competencyId) isMastered) {
  return isMastered('sca.major_formula') && isMastered('sca.c_major') && isMastered('sca.major_g_f');
}

bool pr05StagePlayable(int stage) => stage >= 1 && stage <= 5;
