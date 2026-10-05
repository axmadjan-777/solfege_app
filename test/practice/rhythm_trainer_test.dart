import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/trainers/rhythm_trainer.dart';
import 'package:test/test.dart';

void main() {
  test('onset tolerance is 120 ms early and 90 ms late, offset included', () {
    expect(OnsetJudge.toleranceMs(1), 120);
    expect(OnsetJudge.toleranceMs(5), 90);
    expect(
      OnsetJudge.hit(tapMs: 100, clickMs: 0, latencyOffsetMs: 0, toleranceMs: 120),
      isTrue,
    );
    expect(
      OnsetJudge.hit(tapMs: 130, clickMs: 0, latencyOffsetMs: 0, toleranceMs: 120),
      isFalse,
    );
    expect(
      OnsetJudge.hit(tapMs: 160, clickMs: 0, latencyOffsetMs: 50, toleranceMs: 120),
      isTrue,
    );
    expect(
      OnsetJudge.hit(tapMs: 100, clickMs: 0, latencyOffsetMs: 0, toleranceMs: 90),
      isFalse,
    );
  });

  test('metronome stays at or below 100 BPM and is a synthetic click', () {
    final sequence = metronomeClicks(bpm: 120);
    final rests = sequence.events.whereType<RestEvent>().toList();
    expect(rests.first.durationMs, (60000 / 100).round());
    expect(sequence.events.whereType<NoteEvent>(), isNotEmpty);
  });

  test('PR-09 waits for the pulse lesson and ignores the postponed sixteenth lesson', () {
    expect(pr09CanStart((_) => false), isFalse);
    expect(
      pr09CanStart((id) => id == 'rhy.beat_tempo' || id == 'rhy.eighths'),
      isFalse,
    );
    expect(
      pr09CanStart((id) => id == 'rhy.pulse_tap' || id == 'rhy.beat_tempo' || id == 'rhy.eighths'),
      isTrue,
    );
  });
}
