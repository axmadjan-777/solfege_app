/// Лады как повороты мажора и семь видов септаккордов.
const modes = {
  'ионийский': [0, 2, 4, 5, 7, 9, 11],
  'дорийский': [0, 2, 3, 5, 7, 9, 10],
  'фригийский': [0, 1, 3, 5, 7, 8, 10],
  'лидийский': [0, 2, 4, 6, 7, 9, 11],
  'миксолидийский': [0, 2, 4, 5, 7, 9, 10],
  'эолийский': [0, 2, 3, 5, 7, 8, 10],
  'локрийский': [0, 1, 3, 5, 6, 8, 10],
};

const majorPentatonic = [0, 2, 4, 7, 9];
const minorPentatonic = [0, 3, 5, 7, 10];

const seventhChords = {
  'maj7': [0, 4, 7, 11],
  'min7': [0, 3, 7, 10],
  'dom7': [0, 4, 7, 10],
  'm7b5': [0, 3, 6, 10],
  'dim7': [0, 3, 6, 9],
};

String? modeBySteps(List<int> steps) {
  for (final entry in modes.entries) {
    if (_same(entry.value, steps)) return entry.key;
  }
  return null;
}

String? seventhBySteps(List<int> relativeSteps) {
  final sorted = [...relativeSteps]..sort();
  for (final entry in seventhChords.entries) {
    if (_same(entry.value, sorted)) return entry.key;
  }
  return null;
}

List<int> relativeToBass(List<int> pitches) {
  final bass = pitches.reduce((a, b) => a < b ? a : b);
  return [for (final pitch in pitches) pitch - bass]..sort();
}

bool chromaticStepwise(List<int> pitches) {
  for (var i = 0; i < pitches.length - 1; i++) {
    if (pitches[i + 1] - pitches[i] != 1) return false;
  }
  return pitches.length >= 2;
}

bool _same(List<int> actual, List<int> expected) {
  if (actual.length != expected.length) return false;
  for (var i = 0; i < actual.length; i++) {
    if (actual[i] != expected[i]) return false;
  }
  return true;
}
