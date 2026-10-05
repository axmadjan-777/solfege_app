import '../../scales/utils/solfege_notes.dart';
import '../../scales/utils/treble_staff_layout.dart';

/// Чтение нот PR-08. Бас считается теми же диатоническими шагами, без второй геометрии стана.
class NoteReading {
  const NoteReading._();

  static const f3Midi = 53;
  static const c3Midi = 48;
  static const c4Midi = 60;
  static const g4Midi = 67;

  static String syllable(int midi) => SolfegeNotes.fromMidi(midi, useFlats: false);

  static double trebleY(int midi) => TrebleStaffLayout.yForMidi(midi, topPadding: 8, lineGap: 12);

  /// Положительное значение — выше фа малой октавы.
  static int bassStepsFromF3(int midi) {
    return TrebleStaffLayout.diatonicIndex(midi) - TrebleStaffLayout.diatonicIndex(f3Midi);
  }

  static bool inTrebleC4G4(int midi) => midi >= c4Midi && midi <= g4Midi;

  static bool inBassC3C4(int midi) => midi >= c3Midi && midi <= c4Midi;
}

/// Стадия 6 вне MVP. Старт ждёт четыре урока чтения.
bool pr08StagePlayable(int stage) => stage >= 1 && stage <= 5;

bool pr08CanStart(bool Function(String competencyId) isMastered) {
  return isMastered('not.read_treble_c4_g4') &&
      isMastered('not.read_treble_a4_g5') &&
      isMastered('not.read_bass_c3_c4') &&
      isMastered('not.grand_staff');
}
