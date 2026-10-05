import '../audio/audio_sequence.dart';

/// Натуральный минор: 0, 2, 3, 5, 7, 8, 10. Повышенная VII гармонического — 11.
class MinorDegreeDictation {
  const MinorDegreeDictation._();

  static const natural = [0, 2, 3, 5, 7, 8, 10];
  static const raisedSeventh = 11;

  static String degreeLabel(int tonicMidi, int noteMidi) {
    final distance = (noteMidi - tonicMidi) % 12;
    if (distance == raisedSeventh) return '7#';
    final index = natural.indexOf(distance);
    if (index < 0) return '';
    return '${index + 1}';
  }

  static bool accepts({required int tonicMidi, required int noteMidi, required String answer}) {
    return degreeLabel(tonicMidi, noteMidi) == answer;
  }

  static bool arrivedHome(int tonicMidi, int noteMidi) => degreeLabel(tonicMidi, noteMidi) == '1';

  static AudioSequence prompt({required int noteMidi}) {
    return AudioSequence([
      const ChordEvent([57, 60, 64]),
      const ChordEvent([53, 57, 60]),
      const ChordEvent([55, 59, 62]),
      const ChordEvent([57, 60, 64]),
      const RestEvent(500),
      NoteEvent(noteMidi),
    ]);
  }
}

/// L06-03 имеет статус v1.1, общий замок MVP его пропускает. Здесь он настоящий.
bool pr02CanStart(bool Function(String competencyId) isMastered) => isMastered('sca.minor_degrees');
