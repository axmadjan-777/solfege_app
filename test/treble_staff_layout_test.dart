import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/scales/utils/treble_staff_layout.dart';

void main() {
  const topPadding = 28.0;
  const lineGap = 10.0;

  double y(int midi) => TrebleStaffLayout.yForMidi(
        midi,
        topPadding: topPadding,
        lineGap: lineGap,
      );

  test('G4 anchor sits on 2nd line from bottom', () {
    final g4 = y(67);
    const bottomLine = topPadding + 4 * lineGap;
    const secondFromBottom = topPadding + 3 * lineGap;
    expect(g4, closeTo(secondFromBottom, 0.01));
    expect(g4, isNot(closeTo(bottomLine, 0.01)));
  });

  test('D major ascending positions match treble clef layout', () {
    // ре1 — под 1-й линией, ми1 — на 1-й, фа♯1 — в 1-м промежутке,
    // соль1 — на 2-й, ля1 — во 2-м, си1 — на 3-й, до♯2 — в 3-м, ре2 — на 4-й.
    final notes = [62, 64, 66, 67, 69, 71, 73, 74];
    final ys = notes.map(y).toList();

    for (var i = 0; i < ys.length - 1; i++) {
      expect(ys[i + 1], lessThan(ys[i]));
    }
    expect(ys[7], closeTo(topPadding + 1 * lineGap, 0.01));
    expect(ys[1], closeTo(topPadding + 4 * lineGap, 0.01));
    expect(ys[0], greaterThan(topPadding + 4 * lineGap));
  });

  test('C major first note uses ledger area below staff', () {
    final c4 = y(60);
    const bottomLine = topPadding + 4 * lineGap;
    expect(c4, greaterThan(bottomLine));
  });
}
