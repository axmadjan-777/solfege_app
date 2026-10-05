import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/screens/triad_error_screen.dart';
import 'package:solfege_app/features/practice/trainers/triad_build.dart';
import 'package:solfege_app/features/practice/trainers/triad_formulas.dart';

void main() {
  test('stage 4 opens after stage 2, and stage 3 stays out of MVP', () {
    expect(pr07StageOpen(stage: 3, stage2Passed: true), isFalse);
    expect(pr07StageOpen(stage: 4, stage2Passed: false), isFalse);
    expect(pr07StageOpen(stage: 4, stage2Passed: true), isTrue);
  });

  testWidgets('stage 4 corrects the extra semitone back to 0-4-7', (tester) async {
    const wrong = [60, 65, 67];
    expect(TriadFormulas.classify(wrong), isNull);
    expect(TriadFormulas.classify(correctThird(wrong, TriadFormulas.major)), 'major');

    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: TriadErrorScreen(pitches: wrong, onAnswered: (value) => answer = value),
      ),
    );
    await tester.tap(find.text('60–64–67'));
    await tester.pump();
    expect(answer, isTrue);
  });
}
