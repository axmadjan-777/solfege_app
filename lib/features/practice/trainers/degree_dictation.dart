import '../audio/audio_sequence.dart';

/// Ступени мажора относительно тоники. Октава не меняет номер ступени.
class DegreeDictation {
  const DegreeDictation._();

  static const semitones = [0, 2, 4, 5, 7, 9, 11];

  static int degreeNumber(int tonicMidi, int noteMidi) {
    final distance = (noteMidi - tonicMidi) % 12;
    final index = semitones.indexOf(distance);
    if (index < 0) return -1;
    return index + 1;
  }

  static bool accepts({required int tonicMidi, required int noteMidi, required int answer}) {
    return degreeNumber(tonicMidi, noteMidi) == answer;
  }

  /// Стадия 1: «вернулось домой» только для тоники.
  static bool arrivedHome(int tonicMidi, int noteMidi) => degreeNumber(tonicMidi, noteMidi) == 1;

  static bool passed({required int correct, required int total, required double minAccuracy, required int minItems}) {
    if (total < minItems || total == 0) return false;
    return correct / total >= minAccuracy;
  }

  static bool needsComparison(int correctDegree, int chosenDegree) {
    const pairs = {
      (4, 6),
      (6, 4),
      (2, 7),
      (7, 2),
    };
    return pairs.contains((correctDegree, chosenDegree));
  }

  static int pickMidi({
    required int tonicMidi,
    required int degree,
    required int low,
    required int high,
    int? avoidRegister,
  }) {
    final matches = <int>[];
    for (var midi = low; midi <= high; midi++) {
      if (degreeNumber(tonicMidi, midi) == degree) matches.add(midi);
    }
    if (matches.isEmpty) {
      throw StateError('Ступень $degree не помещается в $low–$high');
    }
    if (avoidRegister != null) {
      final other = matches.where((midi) => _register(midi) != avoidRegister).toList();
      if (other.isNotEmpty) return other.first;
    }
    return matches.first;
  }

  static int _register(int midi) => midi < 60 ? 0 : (midi < 72 ? 1 : 2);

  static AudioSequence prompt({required int tonicMidi, required int noteMidi}) {
    return AudioSequence([
      const ChordEvent(TonalPrompt.cadenceI),
      const ChordEvent(TonalPrompt.cadenceIV),
      const ChordEvent(TonalPrompt.cadenceV),
      const ChordEvent(TonalPrompt.cadenceI),
      const RestEvent(500),
      NoteEvent(noteMidi),
    ]);
  }
}
