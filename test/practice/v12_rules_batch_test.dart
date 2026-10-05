import 'package:solfege_app/features/practice/trainers/harmony_and_melody.dart';
import 'package:solfege_app/features/practice/trainers/rhythm_advanced.dart';
import 'package:test/test.dart';

void main() {
  test('6/8 and 3/4 share six eighths but not the grouping', () {
    expect(eighthsInMeter('6/8'), eighthsInMeter('3/4'));
    expect(beatGroups('6/8'), [3, 3]);
    expect(beatGroups('3/4'), [2, 2, 2]);
    expect(beatGroups('5/4'), [3, 2]);
    expect(eighthsInMeter('7/8'), 7);
  });

  test('a dotted eighth plus a sixteenth is a quarter, and a triplet is not three eighths', () {
    expect(dottedValue(eighth) + sixteenth, quarter);
    expect(eighthTriplet * 3, closeTo(quarter, 1e-9));
    expect(eighth * 3, greaterThan(quarter));
    expect(isSyncopated(const [false, true, false, false, false, false, false, false]), isTrue);
    expect(isSyncopated(const [true, false, true, false, true, false, true, false]), isFalse);
  });

  test('melodic dictation stage 2 allows only 1, 3 and 5 and must end on the tonic', () {
    expect(tonicTriadMelody(const [1, 3, 5, 3, 1]), isTrue);
    expect(tonicTriadMelody(const [1, 2, 3, 1]), isFalse);
    expect(tonicTriadMelody(const [1, 3, 5]), isFalse);
    expect(triadLeap(1, 5), isTrue);
    expect(triadLeap(1, 6), isFalse);
    expect(triadLeap(2, 5), isFalse);
  });

  test('V-I is authentic, IV-I is plagal, V-vi is deceptive, and the bass follows the function', () {
    expect(cadenceType(const ['I', 'V', 'I']), 'authentic');
    expect(cadenceType(const ['I', 'IV', 'I']), 'plagal');
    expect(cadenceType(const ['I', 'V', 'vi']), 'deceptive');
    expect(cadenceType(const ['I', 'IV', 'V']), 'half');
    expect(cadenceType(const ['V', 'I']), isNot('plagal'));
    expect(romanTriad('I'), [60, 64, 67]);
    expect(romanTriad('V'), [67, 71, 74]);
    expect(romanTriad('vi'), [69, 72, 76]);
    expect(bassOf(romanTriad('V')), 67);
    expect(bassOf(romanTriad('IV')), 65);
  });

  test('singing does not score pitch or grant mastered', () {
    expect(singGrantsMastered('спел'), isFalse);
    expect(singGrantsMastered('ещё раз'), isFalse);
    expect(singPrompt('tonic'), 'Спой тонику');
  });

  test('harmonic minor makes the dominant major and the seventh diminished', () {
    expect(naturalMinorTriads[4], 'minor');
    expect(harmonicMinorTriads[4], 'major');
    expect(naturalMinorTriads[6], 'major');
    expect(harmonicMinorTriads[6], 'dim');
    expect(syllableOfDegree(7), 'си');
  });
}
