import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/screens/dictation_stage_screen.dart';

void main() {
  testWidgets('PR-10 stage 1 chooses a transcription and builds the bar', (tester) async {
    bool? finished;
    await tester.pumpWidget(
      MaterialApp(home: DictationStageScreen(onFinished: (value) => finished = value)),
    );
    expect(find.text('Повторов: 3'), findsOneWidget);
    await tester.tap(find.text('запись 2'));
    await tester.pump();
    final quarter = find.widgetWithText(OutlinedButton, 'четверть');
    for (var i = 0; i < 4; i++) {
      await tester.tap(quarter);
      await tester.pump();
    }
    expect(finished, isTrue);
  });
}
