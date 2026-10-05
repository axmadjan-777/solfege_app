import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/screens/note_reading_screen.dart';

void main() {
  testWidgets('stage 1 names C4 as do when the trainer is open', (tester) async {
    String? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteReadingScreen(midi: 60, unlocked: true, onAnswer: (value) => answer = value),
      ),
    );

    expect(find.text('Опоры и соседи (C4–G4)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'до'));
    await tester.pump();
    expect(answer, 'до');
  });

  testWidgets('stage 1 does not start while reading lessons are locked', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteReadingScreen(midi: 60, unlocked: false, onAnswer: (_) {}),
      ),
    );
    expect(find.textContaining('Закрыто'), findsOneWidget);
    expect(find.text('до'), findsNothing);
  });
}
