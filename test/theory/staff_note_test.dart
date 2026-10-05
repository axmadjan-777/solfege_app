import 'package:solfege_app/features/scales/utils/solfege_notes.dart';
import 'package:solfege_app/features/scales/utils/treble_staff_layout.dart';
import 'package:test/test.dart';

void main() {
  test('C4 sits below G4 on the treble staff and is named do', () {
    const gap = 12.0;
    final c4 = TrebleStaffLayout.yForMidi(60, topPadding: 8, lineGap: gap);
    final g4 = TrebleStaffLayout.yForMidi(67, topPadding: 8, lineGap: gap);
    final c5 = TrebleStaffLayout.yForMidi(72, topPadding: 8, lineGap: gap);

    expect(c4, greaterThan(g4));
    expect(g4, greaterThan(c5));
    expect(SolfegeNotes.fromMidi(60, useFlats: false), 'до');
    expect(SolfegeNotes.fromMidi(67, useFlats: false), 'соль');
  });
}
