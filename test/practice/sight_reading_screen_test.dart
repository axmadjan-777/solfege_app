import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/screens/sight_reading_screen.dart';
import 'package:solfege_app/features/practice/trainers/sight_reading.dart';

void main() {
  testWidgets('stage 1 plays four pitches and accepts the phrase', (tester) async {
    final player = FakePracticeAudioPlayer();
    bool? ok;
    await tester.pumpWidget(
      MaterialApp(
        home: SightReadingScreen(
          phrase: const SightPhrase([1, 3, 2, 1]),
          player: player,
          onFinished: (value) => ok = value,
        ),
      ),
    );
    await tester.pump();
    expect(player.played, hasLength(4));
    expect(find.text('4 такта, только высота'), findsOneWidget);
    for (final name in ['до', 'ми', 'ре', 'до']) {
      await tester.tap(find.widgetWithText(FilledButton, name).first);
      await tester.pump();
    }
    expect(ok, isTrue);
  });
}
