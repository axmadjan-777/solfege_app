import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/audio/latency_calibration.dart';
import 'package:solfege_app/features/practice/trainers/interval_ear.dart';
import 'package:test/test.dart';

void main() {
  test('minor third, major third and perfect fifth are 3, 4 and 7 semitones', () {
    expect(IntervalEar.semitones['м3'], 3);
    expect(IntervalEar.semitones['б3'], 4);
    expect(IntervalEar.semitones['ч5'], 7);
    expect(IntervalEar.labelFor(4), 'б3');
  });

  test('a seeded drill stays inside C3–C5 and does not repeat the same interval', () {
    final drill = IntervalDrill(seed: 4, labels: const ['м3', 'б3', 'ч5']);
    final tasks = [for (var i = 0; i < 6; i++) drill.next()];

    expect(tasks.map((task) => task.signature).toSet(), hasLength(6));
    for (final task in tasks) {
      expect(task.bassMidi, inInclusiveRange(48, 72));
      expect(task.upperMidi, inInclusiveRange(48, 72));
      expect(task.upperMidi - task.bassMidi, IntervalEar.semitones[task.label]);
    }
  });

  test('a repeated third plays correct, answer, correct', () {
    final sequence = intervalComparison(bassMidi: 60, correctSemitones: 4, chosenSemitones: 3);
    final notes = sequence.events.whereType<NoteEvent>().map((event) => event.midi).toList();

    expect(notes, [60, 64, 60, 63, 60, 64]);
    expect(sequence.events.whereType<NoteEvent>().map((event) => event.volume).toSet(), {practiceAudioVolume});
  });

  test('stages 1–3 do not wait for level 5, later stages stay ahead', () {
    expect(isEarlyIntervalStage(2), isTrue);
    expect(isEarlyIntervalStage(4), isFalse);
    expect(TapFallback.templates, containsAll(['T02', 'T08']));
  });
}
