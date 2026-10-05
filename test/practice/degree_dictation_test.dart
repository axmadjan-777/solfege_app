import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/trainers/degree_dictation.dart';
import 'package:test/test.dart';

void main() {
  test('C5 is still degree 1 of C and a wrong octave is accepted', () {
    expect(DegreeDictation.degreeNumber(60, 72), 1);
    expect(DegreeDictation.accepts(tonicMidi: 60, noteMidi: 72, answer: 1), isTrue);
    expect(DegreeDictation.degreeNumber(60, 64), 3);
  });

  test('stage 8 moves to another register after two correct answers in one', () {
    final midi = DegreeDictation.pickMidi(
      tonicMidi: 60,
      degree: 1,
      low: 55,
      high: 76,
      avoidRegister: 1,
    );

    expect(midi, inInclusiveRange(55, 76));
    expect(midi, isNot(inInclusiveRange(60, 71)));
    expect(DegreeDictation.degreeNumber(60, midi), 1);
  });

  test('stage 1 prompt hides the note behind the cadence and a 500 ms rest', () {
    final sequence = DegreeDictation.prompt(tonicMidi: 60, noteMidi: 67);
    expect(sequence.events[4], isA<RestEvent>().having((event) => event.durationMs, 'durationMs', 500));
    expect(sequence.events.last, isA<NoteEvent>().having((event) => event.midi, 'midi', 67));
    expect(sequence.events.last, isA<NoteEvent>().having((event) => event.midi, 'midi', inInclusiveRange(60, 72)));
  });

  test('ten of twelve correct answers pass stage 1 and the session is not mastered', () {
    expect(DegreeDictation.passed(correct: 10, total: 12, minAccuracy: 0.8, minItems: 10), isTrue);
    expect(DegreeDictation.passed(correct: 7, total: 10, minAccuracy: 0.8, minItems: 10), isFalse);
    expect(DegreeDictation.needsComparison(4, 6), isTrue);
    expect(DegreeDictation.needsComparison(2, 7), isTrue);
    expect(DegreeDictation.needsComparison(1, 5), isFalse);
  });
}
