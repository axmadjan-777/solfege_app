import '../audio/audio_sequence.dart';

/// Формулы от основного тона. Лишний полутон в терции или квинте — другой вид.
class TriadFormulas {
  const TriadFormulas._();

  static const major = [0, 4, 7];
  static const minor = [0, 3, 7];
  static const diminished = [0, 3, 6];
  static const augmented = [0, 4, 8];

  static const byName = {
    'major': major,
    'minor': minor,
    'dim': diminished,
    'aug': augmented,
  };

  static List<int> relative(List<int> pitches) {
    final root = pitches.reduce((a, b) => a < b ? a : b);
    final steps = [for (final pitch in pitches) pitch - root]..sort();
    return steps;
  }

  static String? classify(List<int> pitches) {
    final steps = relative(pitches);
    for (final entry in byName.entries) {
      if (_same(steps, entry.value)) return entry.key;
    }
    return null;
  }

  static bool _same(List<int> actual, List<int> expected) {
    if (actual.length != expected.length) return false;
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != expected[i]) return false;
    }
    return true;
  }
}

/// Большое/увеличенное и малое/уменьшённое: верный аккорд, ответ, верный аккорд.
AudioSequence triadComparison({
  required int root,
  required List<int> correct,
  required List<int> chosen,
}) {
  ChordEvent chord(List<int> formula) => ChordEvent([for (final step in formula) root + step]);
  return AudioSequence([
    chord(correct),
    chord(chosen),
    chord(correct),
  ]);
}

const pr06Required = [
  'chd.major_triad',
  'chd.minor_triad',
  'chd.compare_major_minor',
  'chd.dim_triad',
  'chd.aug_triad',
  'chd.compare_four_types',
];

bool pr06CanStart(bool Function(String competencyId) isMastered) {
  return pr06Required.every(isMastered);
}

bool pr06StagePlayable(int stage) => stage >= 1 && stage <= 3;
