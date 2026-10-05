import 'package:solfege_app/features/practice/trainers/note_reading.dart';
import 'package:test/test.dart';

void main() {
  test('C4–G4 and bass C3–C4 keep their staff positions', () {
    expect(NoteReading.syllable(60), 'до');
    expect(NoteReading.syllable(67), 'соль');
    expect(NoteReading.trebleY(60), greaterThan(NoteReading.trebleY(67)));
    expect(NoteReading.inTrebleC4G4(60), isTrue);
    expect(NoteReading.inTrebleC4G4(59), isFalse);

    expect(NoteReading.bassStepsFromF3(48), lessThan(0));
    expect(NoteReading.bassStepsFromF3(53), 0);
    expect(NoteReading.bassStepsFromF3(60), greaterThan(0));
    expect(NoteReading.syllable(48), 'до');
    expect(NoteReading.inBassC3C4(48), isTrue);
    expect(NoteReading.inBassC3C4(60), isTrue);
    expect(NoteReading.inBassC3C4(62), isFalse);
  });

  test('stage 6 stays out and the trainer waits for four reading lessons', () {
    expect(pr08StagePlayable(1), isTrue);
    expect(pr08StagePlayable(6), isFalse);
    expect(pr08CanStart((_) => false), isFalse);
    expect(
      pr08CanStart(
        (id) =>
            id == 'not.read_treble_c4_g4' ||
            id == 'not.read_treble_a4_g5' ||
            id == 'not.read_bass_c3_c4' ||
            id == 'not.grand_staff',
      ),
      isTrue,
    );
  });
}
