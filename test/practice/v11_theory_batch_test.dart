import 'package:solfege_app/features/practice/trainers/notation_extras.dart';
import 'package:solfege_app/features/practice/trainers/scale_theory.dart';
import 'package:solfege_app/features/practice/trainers/triad_spelling.dart';
import 'package:test/test.dart';

void main() {
  test('sharps follow fifths and a swapped G-sharp is rejected', () {
    expect(isSharpOrder(const ['фа', 'до', 'соль']), isTrue);
    expect(isSharpOrder(const ['фа', 'соль', 'до']), isFalse);
    expect(isFlatOrder(const ['си', 'ми', 'ля']), isTrue);
    expect(sharpCount(0), 0);
    expect(sharpCount(1), 1);
    expect(sharpCount(2), 2);
  });

  test('harmonic minor raises only the seventh, melodic raises six and seven', () {
    expect(minorKind(harmonicMinorSteps), 'harmonic');
    expect(minorKind(melodicMinorAscending), 'melodic');
    expect(minorKind(naturalMinorSteps), 'natural');
    expect(harmonicMinorSteps[5], naturalMinorSteps[5]);
    expect(harmonicMinorSteps[6], isNot(naturalMinorSteps[6]));
    expect(melodicMinorAscending[5], isNot(naturalMinorSteps[5]));
  });

  test('relative minor is a minor third down, parallel keeps the tonic', () {
    expect(relativeMinor(60), 57);
    expect(isRelativePair(60, 57), isTrue);
    expect(isRelativePair(60, 60), isFalse);
    expect(isParallelPair(60, 60), isTrue);
  });

  test('first inversion puts the third in the bass, second inversion the fifth', () {
    final first = spellTriad(const [64, 67, 72]);
    final second = spellTriad(const [67, 72, 76]);
    expect(first?.quality, 'major');
    expect(first?.position, 'first');
    expect(second?.position, 'second');
    expect(firstInversion(const [60, 64, 67]), [64, 67, 72]);
  });

  test('timbre does not change the chord, and scale degrees keep their quality', () {
    expect(qualityIgnoringTimbre(const [60, 64, 67], 'electric_piano'), 'major');
    expect(qualityIgnoringTimbre(const [60, 64, 67], 'acoustic_grand'), 'major');
    expect(triadOnDegree(tonic: 60, degree: 2), [62, 65, 69]);
    expect(triadOnDegree(tonic: 60, degree: 7), [71, 74, 77]);
    expect(majorScaleTriadQuality[1], 'minor');
    expect(majorScaleTriadQuality[6], 'dim');
  });

  test('a sharp raises F, a natural cancels the key, a dot and a tie add duration', () {
    expect(soundingMidi(65, accidental: 'sharp'), 66);
    expect(soundingMidi(65, accidental: '', keyRaises: true), 66);
    expect(soundingMidi(65, accidental: 'natural', keyRaises: true), 65);
    expect(dotted(1), 1.5);
    expect(tied(const [1.5, 0.5, 2]), 4);
  });
}
