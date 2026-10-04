/// Канонические формулы из части 27. Контент ссылается на них по именам,
/// числа живут здесь одним источником.
class MusicFormulas {
  const MusicFormulas._();

  static const majorScale = [2, 2, 1, 2, 2, 2, 1];
  static const naturalMinor = [2, 1, 2, 2, 1, 2, 2];
  static const harmonicMinor = [2, 1, 2, 2, 1, 3, 1];
  static const melodicMinorAscending = [2, 1, 2, 2, 2, 2, 1];

  static const scales = {
    'major': majorScale,
    'natural_minor': naturalMinor,
    'harmonic_minor': harmonicMinor,
    'melodic_minor_ascending': melodicMinorAscending,
  };

  static const chords = {
    'major': [0, 4, 7],
    'minor': [0, 3, 7],
    'dim': [0, 3, 6],
    'aug': [0, 4, 8],
    'dom7': [0, 4, 7, 10],
    'maj7': [0, 4, 7, 11],
    'min7': [0, 3, 7, 10],
    'm7b5': [0, 3, 6, 10],
    'dim7': [0, 3, 6, 9],
  };

  /// Простые интервалы в полутонах. Русские подписи стадий PR-03.
  static const intervals = {
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
    'ч8': 12,
  };

  static int sum(List<int> steps) => steps.fold(0, (a, b) => a + b);
}
