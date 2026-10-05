import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/screens/interval_choice_screen.dart';
import 'package:solfege_app/features/practice/trainers/interval_ear.dart';

void main() {
  test('later intervals keep their semitone counts and inversions', () {
    expect(IntervalEar.semitones['ч4'], 5);
    expect(IntervalEar.semitones['ч5']! - IntervalEar.semitones['ч4']!, 2);
    expect(IntervalEar.semitones['тритон'], 6);
    expect(IntervalEar.semitones['ч5']! - IntervalEar.semitones['тритон']!, 1);
    expect(IntervalEar.semitones['м6'], 8);
    expect(IntervalEar.semitones['б6'], 9);
    expect(IntervalEar.inversion(IntervalEar.semitones['м2']!),
        IntervalEar.semitones['б7']);
    expect(IntervalEar.inversion(6), 6);
    expect(IntervalEar.stageLabels[7], hasLength(11));
    expect(IntervalEar.stageLabels[4], ['м3', 'б3', 'ч4', 'ч5']);
  });

  test('stages 4–8 wait for interval lessons, stages 1–3 do not', () {
    expect(intervalStageOpen(2, intervalLessonsMastered: false), isTrue);
    expect(intervalStageOpen(4, intervalLessonsMastered: false), isFalse);
    expect(intervalStageOpen(8, intervalLessonsMastered: true), isTrue);
  });

  test('a harmonic fourth is one chord, not two successive notes', () {
    final sequence = intervalPlayback(bassMidi: 60, steps: 5, harmonic: true);
    expect(sequence.events.whereType<NoteEvent>(), isEmpty);
    expect(sequence.events.whereType<ChordEvent>().single.midi, [60, 65]);
  });

  testWidgets('calling a fourth a fifth is wrong and replays both',
      (tester) async {
    final player = FakePracticeAudioPlayer();
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: IntervalChoiceScreen(
          bassMidi: 60,
          steps: 5,
          labels: IntervalEar.stageLabels[4]!,
          harmonic: false,
          player: player,
          onAnswered: (value) => answer = value,
        ),
      ),
    );
    await tester.pump();
    expect(
        player.played
            .whereType<NoteEvent>()
            .map((event) => event.midi)
            .toList(),
        [60, 65]);

    await tester.tap(find.text('ч5'));
    await tester.pump();
    expect(answer, isFalse);
    expect(find.text('Пока не то'), findsOneWidget);
    final compared = player.played
        .whereType<NoteEvent>()
        .map((event) => event.midi)
        .toList();
    expect(compared, [60, 65, 60, 65, 60, 67, 60, 65]);
  });

  testWidgets('ещё раз replays the interval three times', (tester) async {
    final player = FakePracticeAudioPlayer();
    await tester.pumpWidget(
      MaterialApp(
        home: IntervalChoiceScreen(
          bassMidi: 60,
          steps: 3,
          labels: const ['м3', 'б3'],
          harmonic: false,
          player: player,
          onAnswered: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Ещё раз (3)'), findsOneWidget);
    await tester.tap(find.text('Ещё раз (3)'));
    await tester.pump();
    await tester.tap(find.text('Ещё раз (2)'));
    await tester.pump();
    await tester.tap(find.text('Ещё раз (1)'));
    await tester.pump();
    expect(find.text('Повторы кончились'), findsOneWidget);
    expect(player.played.whereType<NoteEvent>(), hasLength(8));
  });
}
