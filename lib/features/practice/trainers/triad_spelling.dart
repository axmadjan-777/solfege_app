import 'triad_formulas.dart';

class SpelledTriad {
  const SpelledTriad({required this.quality, required this.rootPitchClass, required this.position});

  final String quality;
  final int rootPitchClass;

  /// `root`, `first` или `second`.
  final String position;
}

/// Бас определяет обращение. Тембр на качество не влияет.
SpelledTriad? spellTriad(List<int> pitches) {
  if (pitches.length < 3) return null;
  final bass = pitches.reduce((a, b) => a < b ? a : b) % 12;
  final pitchClasses = pitches.map((pitch) => pitch % 12).toSet();
  for (final entry in TriadFormulas.byName.entries) {
    for (final root in pitchClasses) {
      final relative = pitchClasses.map((pitch) => (pitch - root) % 12).toSet();
      final formula = entry.value.toSet();
      if (relative.length != formula.length || !relative.containsAll(formula)) continue;
      final bassStep = (bass - root) % 12;
      final position = bassStep == entry.value[0]
          ? 'root'
          : bassStep == entry.value[1]
              ? 'first'
              : bassStep == entry.value[2]
                  ? 'second'
                  : '';
      if (position.isEmpty) continue;
      return SpelledTriad(quality: entry.key, rootPitchClass: root, position: position);
    }
  }
  return null;
}

String qualityIgnoringTimbre(List<int> pitches, String timbre) {
  return TriadFormulas.classify(pitches) ?? '';
}

/// I мажор, ii минор, iii минор, IV мажор, V мажор, vi минор, vii уменьшённое.
const majorScaleTriadQuality = ['major', 'minor', 'minor', 'major', 'major', 'minor', 'dim'];

List<int> triadOnDegree({required int tonic, required int degree}) {
  const scale = [0, 2, 4, 5, 7, 9, 11];
  final root = tonic + scale[degree - 1];
  final formula = TriadFormulas.byName[majorScaleTriadQuality[degree - 1]]!;
  return [for (final step in formula) root + step];
}

/// Первое обращение: бас — терция, верхний звук на октаву выше основного тона.
List<int> firstInversion(List<int> rootPosition) {
  final sorted = [...rootPosition]..sort();
  return [sorted[1], sorted[2], sorted[0] + 12];
}
