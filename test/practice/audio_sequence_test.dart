import 'dart:math';

import 'package:test/test.dart';
import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/audio/latency_calibration.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';

void main() {
  test('seeded C major prompt is cadence, 500 ms rest, then one note in C4–C5', () async {
    final sequence = TonalPrompt.cMajorDegree(seed: 7);
    final player = FakePracticeAudioPlayer();
    await player.play(sequence);

    expect(player.played, hasLength(6));
    final chords = player.played.take(4).toList();
    expect(chords[0], isA<ChordEvent>().having((e) => e.midi, 'midi', TonalPrompt.cadenceI));
    expect(chords[1], isA<ChordEvent>().having((e) => e.midi, 'midi', TonalPrompt.cadenceIV));
    expect(chords[2], isA<ChordEvent>().having((e) => e.midi, 'midi', TonalPrompt.cadenceV));
    expect(chords[3], isA<ChordEvent>().having((e) => e.midi, 'midi', TonalPrompt.cadenceI));
    for (final event in chords) {
      final chord = event as ChordEvent;
      expect(chord.midi.length, inInclusiveRange(3, 5));
      expect(chord.volume, practiceAudioVolume);
    }
    expect(_pitchClasses(TonalPrompt.cadenceI), containsAll([0, 4, 7]));
    expect(_pitchClasses(TonalPrompt.cadenceIV), containsAll([0, 5, 9]));
    expect(_pitchClasses(TonalPrompt.cadenceV), containsAll([2, 7, 11]));

    expect(player.played[4], isA<RestEvent>().having((e) => e.durationMs, 'durationMs', 500));
    final note = player.played[5] as NoteEvent;
    expect(note.midi, inInclusiveRange(60, 72));
    expect(note.volume, practiceAudioVolume);
    expect(note.midi, 60 + Random(7).nextInt(13));
  });

  test('repeat error plays correct, then the answer, then correct at one volume', () {
    final sequence = TonalPrompt.comparative(correctMidi: 67, chosenMidi: 69);

    expect(sequence.events, hasLength(3));
    expect((sequence.events[0] as NoteEvent).midi, 67);
    expect((sequence.events[1] as NoteEvent).midi, 69);
    expect((sequence.events[2] as NoteEvent).midi, 67);
    expect(sequence.events.whereType<NoteEvent>().map((e) => e.volume).toSet(), {practiceAudioVolume});
  });

  test('eight stable taps store the latency offset on the profile', () {
    const fallback = TapFallback();
    final taps = List<int>.filled(8, 40);
    final updated = fallback.apply(const AudioProfile(), taps);

    expect(updated.audioLatencyOffsetMs, 40);
    expect(fallback.failed(taps), isFalse);
  });

  test('unstable taps keep the profile and name the T02 and T08 fallback', () {
    const fallback = TapFallback();
    const profile = AudioProfile(audioLatencyOffsetMs: 5);
    final taps = [0, 10, 20, 40, 80, 120, 160, 200];

    expect(fallback.failed(taps), isTrue);
    expect(fallback.apply(profile, taps).audioLatencyOffsetMs, 5);
    expect(TapFallback.templates, ['T02', 'T08']);
  });

  test('two correct answers in one register force the next stimulus into another', () {
    final midi = AbsolutePitchGuard.nextStimulus(
      random: Random(3),
      low: 55,
      high: 76,
      consecutiveCorrectInRegister: 2,
      lastRegister: 1,
    );

    expect(midi, inInclusiveRange(55, 76));
    expect(AbsolutePitchGuard.registerOf(midi), isNot(1));
  });

  test('first aural play hides notation and intro rhythm stays at or below 100 BPM', () {
    expect(AbsolutePitchGuard.showNotationOnFirstPlay(), isFalse);
    expect(AbsolutePitchGuard.introRhythmBpm(120), 100);
    expect(AbsolutePitchGuard.introRhythmBpm(84), 84);
  });

  test('unlicensed and post-MVP audio ids stay unloaded', () {
    expect(AudioBankPolicy.allows('AU-02'), isTrue);
    expect(AudioBankPolicy.allows('AU-11'), isFalse);
    expect(AudioBankPolicy.allows('AU-13'), isFalse);
    expect(AudioBankPolicy.allows('AU-14'), isFalse);
    expect(AudioBankPolicy.allows('AU-15'), isFalse);
  });
}

Set<int> _pitchClasses(List<int> midi) => midi.map((note) => note % 12).toSet();
