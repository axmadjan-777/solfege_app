import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/trainers/triad_formulas.dart';
import 'package:test/test.dart';

void main() {
  test('the four triad kinds are exact pitch sets, and an extra semitone is rejected', () {
    expect(TriadFormulas.classify(const [60, 64, 67]), 'major');
    expect(TriadFormulas.classify(const [60, 63, 67]), 'minor');
    expect(TriadFormulas.classify(const [60, 63, 66]), 'dim');
    expect(TriadFormulas.classify(const [60, 64, 68]), 'aug');
    expect(TriadFormulas.relative(const [64, 67, 60]), [0, 4, 7]);
    expect(TriadFormulas.classify(const [60, 65, 67]), isNull);
    expect(TriadFormulas.classify(const [60, 64, 67, 70]), isNull);
  });

  test('a repeated major-versus-augmented error replays correct, answer, correct', () {
    final sequence = triadComparison(
      root: 60,
      correct: TriadFormulas.major,
      chosen: TriadFormulas.augmented,
    );
    final chords = sequence.events.whereType<ChordEvent>().map((event) => event.midi).toList();

    expect(chords, [
      [60, 64, 67],
      [60, 64, 68],
      [60, 64, 67],
    ]);
    expect(sequence.events.whereType<ChordEvent>().map((event) => event.volume).toSet(), {practiceAudioVolume});
  });

  test('PR-06 stage 1 waits for the major triad and ignores the postponed inversion lesson', () {
    expect(pr06StagePlayable(1), isTrue);
    expect(pr06StagePlayable(4), isFalse);
    expect(pr06CanStart(pr06Required.contains), isTrue);
    expect(pr06CanStart((id) => id == 'chd.inversion_second'), isFalse);
    expect(pr06CanStart((id) => pr06Required.contains(id) && id != 'chd.major_triad'), isFalse);
  });
}
