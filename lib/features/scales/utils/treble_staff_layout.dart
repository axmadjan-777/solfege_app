import 'dart:math' as math;

import '../models/key_signature_category.dart';
import 'key_signature_lookup.dart';
import '../models/scale.dart';
import 'solfege_notes.dart';

/// Вертикальные позиции нот в скрипичном ключе.
abstract final class TrebleStaffLayout {
  static const referenceMidi = 67; // G4 на 2-й линейке снизу
  static const referenceLineIndex = 3; // от верхней линейки (0..4)

  /// MIDI диезов при ключе (порядок: фа, до, соль, ре, ля, ми, си).
  static const sharpKeyMidis = [78, 73, 80, 75, 70, 77, 72];

  /// MIDI бемолей при ключе (порядок: си, ми, ля, ре, соль, до, фа).
  static const flatKeyMidis = [70, 75, 68, 73, 66, 71, 64];

  static const sharpKeyNoteNames = [
    'фа-диез',
    'до-диез',
    'соль-диез',
    'ре-диез',
    'ля-диез',
    'ми-диез',
    'си-диез',
  ];

  static const flatKeyNoteNames = [
    'си-бемоль',
    'ми-бемоль',
    'ля-бемоль',
    'ре-бемоль',
    'соль-бемоль',
    'до-бемоль',
    'фа-бемоль',
  ];

  static int diatonicIndex(int midi) {
    final noteName = SolfegeNotes.fromMidi(midi, useFlats: false);
    return diatonicIndexForWrittenNote(midi, noteName);
  }

  static int diatonicIndexForWrittenNote(int midi, String noteName) {
    final letter = SolfegeNotes.letterIndex(noteName);
    final naturalPitchClass = SolfegeNotes.naturalPitchClasses[letter];
    final soundingOctave = midi ~/ 12 - 1;
    var writtenOctave = soundingOctave;
    var smallestDistance = double.infinity;

    for (var octave = soundingOctave - 1;
        octave <= soundingOctave + 1;
        octave++) {
      final naturalMidi = (octave + 1) * 12 + naturalPitchClass;
      final distance = (midi - naturalMidi).abs().toDouble();
      if (distance < smallestDistance) {
        smallestDistance = distance;
        writtenOctave = octave;
      }
    }

    return writtenOctave * 7 + letter;
  }

  static double yForMidi(
    int midi, {
    required double topPadding,
    required double lineGap,
  }) {
    final refY = topPadding + referenceLineIndex * lineGap;
    final steps = diatonicIndex(referenceMidi) - diatonicIndex(midi);
    return refY + steps * (lineGap / 2);
  }

  static double yForWrittenNote(
    int midi,
    String noteName, {
    required double topPadding,
    required double lineGap,
  }) {
    final refY = topPadding + referenceLineIndex * lineGap;
    final steps = diatonicIndex(referenceMidi) -
        diatonicIndexForWrittenNote(midi, noteName);
    return refY + steps * (lineGap / 2);
  }

  static double topStaffLine(double topPadding) => topPadding;

  static double bottomStaffLine(double topPadding, double lineGap) =>
      topPadding + 4 * lineGap;

  static List<int> ledgerLineIndices({
    required int midi,
    required double topPadding,
    required double lineGap,
  }) {
    final y = yForMidi(midi, topPadding: topPadding, lineGap: lineGap);
    final ledgerLines = ledgerLineYsForY(
      y,
      topPadding: topPadding,
      lineGap: lineGap,
    );
    return List.generate(ledgerLines.length, (index) => index);
  }

  static List<double> ledgerLineYsForY(
    double noteY, {
    required double topPadding,
    required double lineGap,
  }) {
    final top = topStaffLine(topPadding);
    final bottom = bottomStaffLine(topPadding, lineGap);
    final ledgerLines = <double>[];

    if (noteY < top - 0.5) {
      for (var y = top - lineGap; y >= noteY - 0.5; y -= lineGap) {
        ledgerLines.add(y);
      }
    } else if (noteY > bottom + 0.5) {
      for (var y = bottom + lineGap; y <= noteY + 0.5; y += lineGap) {
        ledgerLines.add(y);
      }
    }
    return ledgerLines;
  }

  static double ledgerY({
    required int index,
    required bool aboveStaff,
    required double topPadding,
    required double lineGap,
  }) {
    if (aboveStaff) {
      return topStaffLine(topPadding) - (index + 1) * lineGap;
    }
    return bottomStaffLine(topPadding, lineGap) + (index + 1) * lineGap;
  }

  static List<int> keySignatureMidis(Scale scale) {
    final info = KeySignatureLookup.forScale(scale);
    if (info.signCount == 0) return const [];
    final source = info.isFlat ? flatKeyMidis : sharpKeyMidis;
    return source.sublist(0, info.signCount);
  }

  static List<String> keySignatureNoteNames(Scale scale) {
    final info = KeySignatureLookup.forScale(scale);
    if (info.signCount == 0) return const [];
    final source = info.isFlat ? flatKeyNoteNames : sharpKeyNoteNames;
    return source.sublist(0, info.signCount);
  }

  static String accidentalSymbol(KeySignatureCategory category) {
    return category == KeySignatureCategory.flats ? '♭' : '♯';
  }

  static double minStaffHeight({
    required List<int> midiNotes,
    List<String>? noteNames,
    required double topPadding,
    required double lineGap,
  }) {
    if (noteNames != null && noteNames.length != midiNotes.length) {
      throw ArgumentError('Для каждого MIDI требуется имя записанной ноты');
    }
    var minY = topPadding;
    var maxY = topPadding + 4 * lineGap;
    for (var i = 0; i < midiNotes.length; i++) {
      final y = noteNames == null
          ? yForMidi(
              midiNotes[i],
              topPadding: topPadding,
              lineGap: lineGap,
            )
          : yForWrittenNote(
              midiNotes[i],
              noteNames[i],
              topPadding: topPadding,
              lineGap: lineGap,
            );
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    final extraTop = math.max(0.0, topStaffLine(topPadding) - minY);
    final extraBottom =
        math.max(0.0, maxY - bottomStaffLine(topPadding, lineGap));
    return topPadding * 2 + 4 * lineGap + extraTop + extraBottom + 16;
  }
}
