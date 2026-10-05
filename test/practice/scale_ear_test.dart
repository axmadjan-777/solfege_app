import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/trainers/scale_ear.dart';
import 'package:test/test.dart';

void main() {
  const majorWords = ['тон', 'тон', 'полутон', 'тон', 'тон', 'тон', 'полутон'];

  test('III–IV and VII–I are the only semitones in the major formula', () {
    final sizes = formulaSemitones(majorWords);

    expect(sizes, [2, 2, 1, 2, 2, 2, 1]);
    expect(sizes[2], 1);
    expect(sizes[6], 1);
    expect(sizes.where((size) => size == 2), hasLength(5));
    expect(isMajorFormula(majorWords), isTrue);
  });

  test('a tone between III and IV is not major', () {
    expect(
      isMajorFormula(const ['тон', 'тон', 'тон', 'полутон', 'тон', 'тон', 'полутон']),
      isFalse,
    );
  });

  test('the third decides major or minor, and the hearing context matches it', () {
    expect(isMajorByThird(const [2, 2, 1, 2, 2, 2, 1]), isTrue);
    expect(isMajorByThird(const [2, 1, 2, 2, 1, 2, 2]), isFalse);

    final minor = scaleHearingContext(major: false);
    final notes = minor.events.whereType<NoteEvent>().map((event) => event.midi).toList();
    final chord = minor.events.whereType<ChordEvent>().single.midi;

    expect(notes, [60, 62, 63, 65, 67]);
    expect(chord, [60, 63, 67]);
    expect(notes, hasLength(5));
  });

  test('stages 1–2 wait for three major lessons and ignore postponed minor lessons', () {
    expect(pr05StagePlayable(2), isTrue);
    expect(pr05StagePlayable(3), isFalse);
    expect(
      pr05CanStart((id) => id == 'sca.major_formula' || id == 'sca.c_major' || id == 'sca.major_g_f'),
      isTrue,
    );
    expect(pr05CanStart((id) => id == 'sca.minor_natural'), isFalse);
    expect(pr05CanStart((id) => id == 'sca.major_formula' || id == 'sca.c_major'), isFalse);
  });
}
