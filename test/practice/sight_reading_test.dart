import 'package:solfege_app/features/practice/trainers/sight_reading.dart';
import 'package:test/test.dart';

void main() {
  test('a phrase must end on the tonic and must not leap a tritone', () {
    expect(const SightPhrase([1, 3, 2, 1]).isAllowed, isTrue);
    expect(const SightPhrase([1, 2, 3]).isAllowed, isFalse);
    expect(const SightPhrase([1, 4, 7, 1]).isAllowed, isFalse);
    expect(const SightPhrase([2, 6, 1]).isAllowed, isFalse);
  });

  test('stages 1 and 2 open from the rhythm-and-pitch lesson only', () {
    expect(pr13StagePlayable(1), isTrue);
    expect(pr13StagePlayable(3), isFalse);
    expect(pr13CanStart((id) => id == 'not.read_with_rhythm'), isTrue);
    expect(pr13CanStart((id) => id == 'rea.prehearing'), isFalse);
  });
}
