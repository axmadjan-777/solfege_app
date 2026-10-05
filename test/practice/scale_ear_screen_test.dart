import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/screens/scale_ear_screen.dart';

void main() {
  testWidgets('stage 2 plays five notes and a minor triad, and a major guess is wrong', (tester) async {
    final player = FakePracticeAudioPlayer();
    final answers = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ScaleEarScreen(major: false, player: player, onAnswered: answers.add),
      ),
    );
    await tester.pump();

    final notes = player.played.whereType<NoteEvent>().map((event) => event.midi).toList();
    final chord = player.played.whereType<ChordEvent>().single.midi;
    expect(notes, [60, 62, 63, 65, 67]);
    expect(chord, [60, 63, 67]);

    await tester.tap(find.text('мажор'));
    await tester.pump();
    expect(answers, [false]);
    expect(find.text('Пока не то'), findsOneWidget);
  });

  testWidgets('stage 2 accepts minor after the minor context', (tester) async {
    final player = FakePracticeAudioPlayer();
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: ScaleEarScreen(major: false, player: player, onAnswered: (value) => answer = value),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('минор'));
    await tester.pump();
    expect(answer, isTrue);
    expect(find.text('Верно'), findsOneWidget);
    expect(player.played.whereType<ChordEvent>().single.midi, [60, 63, 67]);
  });
}
