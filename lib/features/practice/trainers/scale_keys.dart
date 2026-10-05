import '../../scales/utils/solfege_notes.dart';
import '../audio/audio_sequence.dart';
import 'scale_ear.dart';

/// Диезы: квинты вверх от фа. Бемоли — тот же ряд назад.
const sharpOrder = ['фа', 'до', 'соль', 'ре', 'ля', 'ми', 'си'];
const flatOrder = ['си', 'ми', 'ля', 'ре', 'соль', 'до', 'фа'];

const naturalMinorSteps = [2, 1, 2, 2, 1, 2, 2];
const harmonicMinorSteps = [2, 1, 2, 2, 1, 3, 1];
const melodicAscendingSteps = [2, 1, 2, 2, 2, 2, 1];

enum MinorForm { natural, harmonic, melodic }

const sharpOrderFeedback = 'Верно, порядок диезов: фа-до-соль-ре-ля-ми-си.';
const sharpOrderFirstError = 'Знаки при ключе ставятся в строгом порядке.';
const sharpOrderRepeatError =
    'Ты поставил соль-диез перед до-диезом. Порядок диезов — по квинтам вверх от фа.';

const harmonicFeedback = 'Верно: в гармоническом миноре повышена только VII.';
const harmonicFirstError = 'Проверь VI и VII ступени.';
const harmonicRepeatError =
    'Ты повысил и VI, и VII — это мелодический минор. В гармоническом повышается только VII.';

const relativeFeedback = 'Верно: параллельный минор — малая терция вниз при тех же знаках.';
const relativeFirstError = 'Параллельные тональности имеют одинаковые знаки.';
const relativeRepeatError =
    'Ты назвал одноимённую тональность (та же тоника, другой лад), а нужна параллельная — та же тональность знаков.';

bool sameOrder(List<String> placed, List<String> expected) {
  if (placed.length != expected.length) return false;
  for (var i = 0; i < placed.length; i++) {
    if (placed[i] != expected[i]) return false;
  }
  return true;
}

List<String> signaturePrefix({required bool sharps, required int count}) {
  final order = sharps ? sharpOrder : flatOrder;
  return order.take(count).toList();
}

/// Соль-диез раньше до-диеза нарушает порядок квинт.
bool gSharpBeforeCSharp(List<String> placed) {
  final g = placed.indexOf('соль');
  final c = placed.indexOf('до');
  return g >= 0 && c >= 0 && g < c;
}

int mod12(int value) => (value % 12 + 12) % 12;

int syllablePitch(String name) {
  const pitches = {
    'до': 0,
    'до-диез': 1,
    'ре-бемоль': 1,
    'ре': 2,
    'ре-диез': 3,
    'ми-бемоль': 3,
    'ми': 4,
    'фа': 5,
    'фа-диез': 6,
    'соль-бемоль': 6,
    'соль': 7,
    'соль-диез': 8,
    'ля-бемоль': 8,
    'ля': 9,
    'ля-диез': 10,
    'си-бемоль': 10,
    'си': 11,
    'до-бемоль': 11,
  };
  final pitch = pitches[name];
  if (pitch == null) {
    throw ArgumentError.value(name, 'name', 'Неизвестное имя тоники');
  }
  return pitch;
}

String spellPitch(int pitch, {required bool flats}) {
  return SolfegeNotes.fromMidi(mod12(pitch), useFlats: flats);
}

/// Последний диез — вводный тон, тоника на полутон выше него.
String majorFromSharpCount(int count) {
  if (count == 0) return 'до';
  final letter = sharpOrder[count - 1];
  final leadingTone = mod12(syllablePitch(letter) + 1);
  return spellPitch(leadingTone + 1, flats: false);
}

/// Предпоследний бемоль — сама мажорная тоника. Один бемоль — фа.
String majorFromFlatCount(int count) {
  if (count == 0) return 'до';
  if (count == 1) return 'фа';
  return '${flatOrder[count - 2]}-бемоль';
}

bool usesFlats(String tonic) => tonic.contains('бемоль') || tonic == 'фа';

const sharpMajors = ['до', 'соль', 'ре', 'ля', 'ми', 'си', 'фа-диез', 'до-диез'];
const flatMajors = ['до', 'фа', 'си-бемоль', 'ми-бемоль', 'ля-бемоль', 'ре-бемоль', 'соль-бемоль', 'до-бемоль'];

String fifthUp(String tonic) {
  final sharpIndex = sharpMajors.indexOf(tonic);
  if (sharpIndex >= 0 && sharpIndex < sharpMajors.length - 1) return sharpMajors[sharpIndex + 1];
  final flatIndex = flatMajors.indexOf(tonic);
  if (flatIndex > 0) return flatMajors[flatIndex - 1];
  throw ArgumentError.value(tonic, 'tonic', 'Нет шага по квинтам вверх');
}

String fifthDown(String tonic) {
  final flatIndex = flatMajors.indexOf(tonic);
  if (flatIndex >= 0 && flatIndex < flatMajors.length - 1) return flatMajors[flatIndex + 1];
  final sharpIndex = sharpMajors.indexOf(tonic);
  if (sharpIndex > 0) return sharpMajors[sharpIndex - 1];
  throw ArgumentError.value(tonic, 'tonic', 'Нет шага по квинтам вниз');
}

/// Параллельный минор: малая терция вниз, те же знаки.
String relativeMinor(String major) {
  return spellPitch(syllablePitch(major) - 3, flats: usesFlats(major));
}

/// Одноимённый минор: та же тоника, другой лад.
bool isParallelMinor(String major, String minor) => major == minor;

bool isRelativeMinor(String major, String minor) => relativeMinor(major) == minor;

int relativeMinorMidi(int majorTonic) => majorTonic - 3;

int signatureCount(String major) {
  final sharpIndex = sharpMajors.indexOf(major);
  if (sharpIndex >= 0) return sharpIndex;
  final flatIndex = flatMajors.indexOf(major);
  if (flatIndex > 0) return flatIndex;
  throw ArgumentError.value(major, 'major', 'Нет такой мажорной тональности в круге');
}

bool sameSignature(String major, String minor) => isRelativeMinor(major, minor);

List<int> scaleMidi(int tonic, List<int> steps) {
  final notes = <int>[tonic];
  var midi = tonic;
  for (final step in steps) {
    midi += step;
    notes.add(midi);
  }
  return notes;
}

List<int> stepsOf(MinorForm form) {
  return switch (form) {
    MinorForm.natural => naturalMinorSteps,
    MinorForm.harmonic => harmonicMinorSteps,
    MinorForm.melodic => melodicAscendingSteps,
  };
}

int degreeOffset(List<int> steps, int degree) {
  var sum = 0;
  for (var i = 0; i < degree - 1; i++) {
    sum += steps[i];
  }
  return sum;
}

bool onlySeventhRaised(List<int> steps) {
  return steps.length == 7 && degreeOffset(steps, 6) == 8 && degreeOffset(steps, 7) == 11;
}

bool sixthAndSeventhRaised(List<int> steps) {
  return steps.length == 7 && degreeOffset(steps, 6) > 8 && degreeOffset(steps, 7) > 10;
}

bool matchesMinor(MinorForm form, List<int> steps) {
  final expected = stepsOf(form);
  return sameInts(steps, expected);
}

bool sameInts(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

/// Вверх — вид, который просили. Мелодический вниз возвращается к натуральному.
AudioSequence minorUpAndDown(int tonic, MinorForm form) {
  final up = scaleMidi(tonic, stepsOf(form));
  final downSteps = form == MinorForm.melodic ? naturalMinorSteps : stepsOf(form);
  final down = scaleMidi(tonic, downSteps).reversed.skip(1);
  return AudioSequence([
    for (final midi in up) NoteEvent(midi),
    for (final midi in down) NoteEvent(midi),
  ]);
}

String stepName(int size) {
  return switch (size) {
    1 => 'полутон',
    2 => 'тон',
    3 => 'полтора',
    _ => throw ArgumentError.value(size, 'size', 'Шаг минора — полутон, тон или полтора'),
  };
}

int stepSize(String name) {
  return switch (name) {
    'полутон' => 1,
    'тон' => 2,
    'полтора' => 3,
    _ => throw ArgumentError.value(name, 'name', 'Ожидался тон, полутон или полтора'),
  };
}

bool meetsStagePass({
  required int correct,
  required int answered,
  double minAccuracy = 0.85,
  int minItems = 12,
}) {
  if (answered < minItems || answered == 0) return false;
  return correct / answered >= minAccuracy;
}

/// Стадии 3–5 ждут освоенные уроки уровня 6. Стадии 1–2 их не ждут. Стадия 6 — v2.
bool pr05LaterStageOpen(int stage, bool Function(String competencyId) isMastered) {
  return switch (stage) {
    1 || 2 => pr05CanStart(isMastered),
    3 => isMastered('sca.key_signatures'),
    4 =>
      isMastered('sca.minor_natural') &&
          isMastered('sca.minor_harmonic') &&
          isMastered('sca.minor_melodic'),
    5 => isMastered('sca.relative_keys') && isMastered('sca.circle_of_fifths'),
    _ => false,
  };
}
