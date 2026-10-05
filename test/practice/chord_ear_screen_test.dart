import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/screens/chord_ear_screen.dart';
import 'package:solfege_app/features/practice/trainers/triad_formulas.dart';

void main() {
  testWidgets('stage 1 sounds a minor triad and rejects calling it major', (tester) async {
    final player = FakePracticeAudioPlayer();
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: ChordEarScreen(
          pitches: const [60, 63, 67],
          player: player,
          onAnswered: (value) => answer = value,
        ),
      ),
    );
    await tester.pump();

    expect(player.played.whereType<ChordEvent>().single.midi, [60, 63, 67]);
    expect(TriadFormulas.classify(const [60, 63, 67]), 'minor');
    await tester.tap(find.text('большое'));
    await tester.pump();
    expect(answer, isFalse);
    expect(find.text('Пока не то'), findsOneWidget);
  });
}
