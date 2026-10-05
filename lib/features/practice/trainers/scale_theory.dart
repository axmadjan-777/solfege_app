/// Порядок диезов и бемолей, три вида минора и параллельные тональности.
const sharpOrder = ['фа', 'до', 'соль', 'ре', 'ля', 'ми', 'си'];
const flatOrder = ['си', 'ми', 'ля', 'ре', 'соль', 'до', 'фа'];

bool isSharpOrder(List<String> names) {
  if (names.length > sharpOrder.length) return false;
  for (var i = 0; i < names.length; i++) {
    if (names[i] != sharpOrder[i]) return false;
  }
  return names.isNotEmpty;
}

bool isFlatOrder(List<String> names) {
  if (names.length > flatOrder.length) return false;
  for (var i = 0; i < names.length; i++) {
    if (names[i] != flatOrder[i]) return false;
  }
  return names.isNotEmpty;
}

const naturalMinorSteps = [0, 2, 3, 5, 7, 8, 10];
const harmonicMinorSteps = [0, 2, 3, 5, 7, 8, 11];
const melodicMinorAscending = [0, 2, 3, 5, 7, 9, 11];

String minorKind(List<int> steps) {
  if (_same(steps, naturalMinorSteps)) return 'natural';
  if (_same(steps, harmonicMinorSteps)) return 'harmonic';
  if (_same(steps, melodicMinorAscending)) return 'melodic';
  return '';
}

bool _same(List<int> actual, List<int> expected) {
  if (actual.length != expected.length) return false;
  for (var i = 0; i < actual.length; i++) {
    if (actual[i] != expected[i]) return false;
  }
  return true;
}

/// Параллельный минор — малая терция вниз, та же тоника не подходит.
int relativeMinor(int majorTonic) => majorTonic - 3;

bool isRelativePair(int majorTonic, int minorTonic) => (majorTonic - minorTonic) % 12 == 3;

bool isParallelPair(int majorTonic, int minorTonic) => majorTonic % 12 == minorTonic % 12;

/// На квинту вверх прибавляется один диез. До — 0, соль — 1, ре — 2.
int sharpCount(int fifthsAboveC) => fifthsAboveC;
