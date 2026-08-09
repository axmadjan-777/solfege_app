import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/scales/utils/treble_staff_layout.dart';

void main() {
  const topPadding = 28.0;
  const lineGap = 10.0;

  double y(int midi, String noteName) => TrebleStaffLayout.yForWrittenNote(
        midi,
        noteName,
        topPadding: topPadding,
        lineGap: lineGap,
      );

  test('G4 anchor sits on 2nd line from bottom', () {
    final g4 = y(67, 'соль');
    const bottomLine = topPadding + 4 * lineGap;
    const secondFromBottom = topPadding + 3 * lineGap;
    expect(g4, closeTo(secondFromBottom, 0.01));
    expect(g4, isNot(closeTo(bottomLine, 0.01)));
  });

  test('C4 through C6 follows consecutive lines and spaces from reference', () {
    final midis = [
      60, 62, 64, 65, 67, 69, 71,
      72, 74, 76, 77, 79, 81, 83, 84,
    ];
    final names = [
      'до', 'ре', 'ми', 'фа', 'соль', 'ля', 'си',
      'до', 'ре', 'ми', 'фа', 'соль', 'ля', 'си', 'до',
    ];
    final ys = [
      for (var i = 0; i < midis.length; i++) y(midis[i], names[i]),
    ];

    for (var i = 0; i < ys.length - 1; i++) {
      expect(ys[i] - ys[i + 1], closeTo(lineGap / 2, 0.01));
    }

    expect(ys.first, closeTo(topPadding + 5 * lineGap, 0.01));
    expect(ys[2], closeTo(topPadding + 4 * lineGap, 0.01));
    expect(ys[4], closeTo(topPadding + 3 * lineGap, 0.01));
    expect(ys.last, closeTo(topPadding - 2 * lineGap, 0.01));
  });

  test('enharmonic spellings use different staff positions', () {
    expect(y(63, 'ре-диез'), closeTo(topPadding + 4.5 * lineGap, 0.01));
    expect(y(63, 'ми-бемоль'), closeTo(topPadding + 4 * lineGap, 0.01));
    expect(y(70, 'ля-диез'), closeTo(topPadding + 2.5 * lineGap, 0.01));
    expect(y(70, 'си-бемоль'), closeTo(topPadding + 2 * lineGap, 0.01));
  });

  test('written octave is correct across C-flat and B-sharp boundaries', () {
    expect(y(59, 'до-бемоль'), closeTo(topPadding + 5 * lineGap, 0.01));
    expect(y(60, 'си-диез'), closeTo(topPadding + 5.5 * lineGap, 0.01));
  });

  test('ledger lines are drawn only on line positions', () {
    List<double> ledgerLines(double noteY) =>
        TrebleStaffLayout.ledgerLineYsForY(
          noteY,
          topPadding: topPadding,
          lineGap: lineGap,
        );

    expect(ledgerLines(y(62, 'ре')), isEmpty);
    expect(ledgerLines(y(60, 'до')), [topPadding + 5 * lineGap]);
    expect(ledgerLines(y(59, 'си')), [topPadding + 5 * lineGap]);
    expect(ledgerLines(y(81, 'ля')), [topPadding - lineGap]);
    expect(
      ledgerLines(y(84, 'до')),
      [topPadding - lineGap, topPadding - 2 * lineGap],
    );
  });

  test('sharp key signature uses conventional treble-clef octaves', () {
    expect(
      TrebleStaffLayout.sharpKeyMidis,
      [78, 73, 80, 75, 70, 77, 72],
    );
  });
}
