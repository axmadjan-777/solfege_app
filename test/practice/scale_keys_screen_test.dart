import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/screens/scale_keys_screen.dart';
import 'package:solfege_app/features/practice/trainers/scale_keys.dart';

void main() {
  testWidgets('putting G-sharp before C-sharp is rejected', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: SharpOrderScreen(
          pool: const ['соль', 'до'],
          expected: signaturePrefix(sharps: true, count: 2),
          onAnswered: (value) => answer = value,
        ),
      ),
    );
    await tester.tap(find.text('соль'));
    await tester.pump();
    await tester.tap(find.text('до'));
    await tester.pump();
    expect(answer, isFalse);
    expect(find.text(sharpOrderRepeatError), findsOneWidget);
  });

  testWidgets('raising both VI and VII is not harmonic, and the scale plays up and down', (tester) async {
    final player = FakePracticeAudioPlayer();
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: MinorBuilderScreen(
          form: MinorForm.harmonic,
          tonic: 60,
          player: player,
          onAnswered: (value) => answer = value,
        ),
      ),
    );
    for (final step in ['тон', 'полутон', 'тон', 'тон', 'тон', 'тон', 'полутон']) {
      await tester.tap(find.text(step));
      await tester.pump();
    }
    expect(answer, isFalse);
    expect(find.text(harmonicRepeatError), findsOneWidget);
    final notes = player.played.whereType<NoteEvent>().map((event) => event.midi).toList();
    expect(notes, [60, 62, 63, 65, 67, 68, 71, 72, 71, 68, 67, 65, 63, 62, 60]);
  });

  testWidgets('naming the parallel minor is not the relative minor', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: RelativeKeyScreen(
          major: 'до',
          choices: const ['ля', 'до'],
          onAnswered: (value) => answer = value,
        ),
      ),
    );
    await tester.tap(find.text('до минор'));
    await tester.pump();
    expect(answer, isFalse);
    expect(find.text(relativeRepeatError), findsOneWidget);
  });
}
