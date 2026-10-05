import 'package:solfege_app/features/practice/trainers/modes_and_sevenths.dart';
import 'package:solfege_app/features/practice/trainers/v2_analysis.dart';
import 'package:test/test.dart';

void main() {
  test('dorian lowers the third and mixolydian lowers the seventh', () {
    expect(modeBySteps(modes['дорийский']!), 'дорийский');
    expect(modeBySteps(modes['миксолидийский']!), 'миксолидийский');
    expect(modes['дорийский']![2], 3);
    expect(modes['ионийский']![2], 4);
    expect(modes['миксолидийский']![6], 10);
    expect(modes['ионийский']![6], 11);
    expect(modeBySteps(modes['дорийский']!), isNot('миксолидийский'));
  });

  test('pentatonic skips two degrees and the chromatic scale moves by single semitones', () {
    expect(majorPentatonic, [0, 2, 4, 7, 9]);
    expect(minorPentatonic, [0, 3, 5, 7, 10]);
    expect(chromaticStepwise(const [60, 61, 62, 63]), isTrue);
    expect(chromaticStepwise(const [60, 62, 64]), isFalse);
  });

  test('a dominant seventh is not a major triad, and the five sevenths stay distinct', () {
    expect(seventhBySteps(relativeToBass(const [60, 64, 67, 70])), 'dom7');
    expect(seventhBySteps(relativeToBass(const [60, 64, 67])), isNull);
    expect(seventhBySteps(const [0, 4, 7, 11]), 'maj7');
    expect(seventhBySteps(const [0, 3, 7, 10]), 'min7');
    expect(seventhBySteps(const [0, 3, 6, 10]), 'm7b5');
    expect(seventhBySteps(const [0, 3, 6, 9]), 'dim7');
    expect(seventhChords.keys, hasLength(5));
  });

  test('a melody note must belong to its chord, and a new tonic is a modulation', () {
    expect(noteBelongsToChord(76, const [60, 64, 67]), isTrue);
    expect(noteBelongsToChord(65, const [60, 64, 67]), isFalse);
    expect(hasModulated(60, 67), isTrue);
    expect(hasModulated(60, 72), isFalse);
    expect(tonicAFifthUp(60), 67);
  });

  test('first sight-reading hides the answer, and singing an interval is not graded', () {
    const reading = FirstReading();
    expect(reading.replaysBeforeAttempt(0), 0);
    expect(reading.revealOnlyAfterAttempt(0), isFalse);
    expect(reading.revealOnlyAfterAttempt(1), isTrue);
    expect(expectedSungMidi(60, 4), 64);
    expect(singAttemptGrantsMastered(), isFalse);
  });
}
