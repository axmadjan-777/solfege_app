import 'package:solfege_app/features/practice/trainers/rhythm_dictation.dart';
import 'package:test/test.dart';

void main() {
  test('a 4/4 bar sums to 4 and names the wrong bar', () {
    expect(RhythmDictation.sum(const ['четверть', 'четверть', 'половинная']), 4);
    expect(RhythmDictation.barFits(const ['восьмая', 'восьмая', 'четверть', 'половинная'], beatsInBar: 4), isTrue);
    expect(RhythmDictation.barFits(const ['четверть', 'четверть'], beatsInBar: 4), isFalse);
    expect(
      RhythmDictation.wrongBar(
        const [
          ['четверть', 'четверть', 'половинная'],
          ['четверть', 'четверть'],
        ],
        beatsInBar: const [4, 4],
      ),
      2,
    );
    expect(
      RhythmDictation.wrongBar(
        const [
          ['четверть', 'четверть', 'половинная'],
        ],
        beatsInBar: const [4],
      ),
      isNull,
    );
    expect(RhythmDictation.stimulusReplays, 3);
  });
}
