import 'dart:math' as math;

import '../models/key_signature_category.dart';
import 'key_signature_lookup.dart';
import '../models/scale.dart';

/// Вертикальные позиции нот в скрипичном ключе.
abstract final class TrebleStaffLayout {
  static const referenceMidi = 67; // G4 на 2-й линейке снизу
  static const referenceLineIndex = 3; // от верхней линейки (0..4)

  /// MIDI диезов при ключе (порядок: фа, до, соль, ре, ля, ми, си).
  static const sharpKeyMidis = [78, 85, 80, 87, 82, 89, 84];

  /// MIDI бемолей при ключе (порядок: си, ми, ля, ре, соль, до, фа).
  static const flatKeyMidis = [70, 75, 68, 73, 66, 71, 64];

  static int diatonicIndex(int midi) {
    const pcToLetter = <int, int>{
      0: 0,
      1: 0,
      2: 1,
      3: 1,
      4: 2,
      5: 3,
      6: 3,
      7: 4,
      8: 4,
      9: 5,
      10: 5,
      11: 6,
    };
    final octave = midi ~/ 12 - 1;
    return octave * 7 + pcToLetter[midi % 12]!;
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

  static double topStaffLine(double topPadding) => topPadding;

  static double bottomStaffLine(double topPadding, double lineGap) =>
      topPadding + 4 * lineGap;

  static List<int> ledgerLineIndices({
    required int midi,
    required double topPadding,
    required double lineGap,
  }) {
    final y = yForMidi(midi, topPadding: topPadding, lineGap: lineGap);
    final top = topStaffLine(topPadding);
    final bottom = bottomStaffLine(topPadding, lineGap);
    final half = lineGap / 2;
    final indices = <int>[];

    if (y < top - 0.5) {
      for (var ledgerY = top - half; ledgerY >= y - 0.5; ledgerY -= half) {
        indices.add(((ledgerY - top) / half).round());
      }
    } else if (y > bottom + 0.5) {
      for (var ledgerY = bottom + half; ledgerY <= y + 0.5; ledgerY += half) {
        indices.add(((ledgerY - bottom) / half).round());
      }
    }
    return indices;
  }

  static double ledgerY({
    required int index,
    required bool aboveStaff,
    required double topPadding,
    required double lineGap,
  }) {
    final half = lineGap / 2;
    if (aboveStaff) {
      return topStaffLine(topPadding) - (index + 1) * half;
    }
    return bottomStaffLine(topPadding, lineGap) + (index + 1) * half;
  }

  static List<int> keySignatureMidis(Scale scale) {
    final info = KeySignatureLookup.forScale(scale);
    if (info.signCount == 0) return const [];
    final source = info.isFlat ? flatKeyMidis : sharpKeyMidis;
    return source.sublist(0, info.signCount);
  }

  static String accidentalSymbol(KeySignatureCategory category) {
    return category == KeySignatureCategory.flats ? '♭' : '♯';
  }

  static double minStaffHeight({
    required List<int> midiNotes,
    required double topPadding,
    required double lineGap,
  }) {
    var minY = topPadding;
    var maxY = topPadding + 4 * lineGap;
    for (final midi in midiNotes) {
      final y = yForMidi(midi, topPadding: topPadding, lineGap: lineGap);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    final extraTop = math.max(0.0, topStaffLine(topPadding) - minY);
    final extraBottom = math.max(0.0, maxY - bottomStaffLine(topPadding, lineGap));
    return topPadding * 2 + 4 * lineGap + extraTop + extraBottom + 16;
  }
}
