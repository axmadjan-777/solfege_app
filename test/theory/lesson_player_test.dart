import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/theory/session/lesson_player.dart';
import 'package:solfege_app/features/theory/session/lesson_script.dart';

void main() {
  testWidgets('T01 lesson ends with train button and records an attempt below mastered', (tester) async {
    final script = LessonScript.sampleT01();
    expect(script.explanationSeconds, lessThanOrEqualTo(120));
    expect(script.steps.where((s) => s.kind == LessonStepKind.warmup).length, inInclusiveRange(2, 3));
    expect(script.steps.where((s) => s.kind == LessonStepKind.guided).length, inInclusiveRange(6, 12));
    expect(script.steps.where((s) => s.kind == LessonStepKind.check).length, inInclusiveRange(2, 4));
    expect(script.steps.where((s) => s.kind == LessonStepKind.transfer), hasLength(1));
    expect(script.steps.where((s) => s.kind == LessonStepKind.guided).every((s) => s.allowsHint), isTrue);
    expect(script.steps.where((s) => s.kind == LessonStepKind.check).every((s) => s.allowsHint), isFalse);

    LessonAttempt? recorded;
    await tester.pumpWidget(
      MaterialApp(
        home: LessonPlayer(script: script, onFinished: (attempt) => recorded = attempt),
      ),
    );

    await tester.tap(find.text('Дальше'));
    await tester.pump();

    while (find.text('Тренировать').evaluate().isEmpty) {
      await tester.tap(find.text('Верный ответ'));
      await tester.pump();
      await tester.tap(find.text('Дальше'));
      await tester.pump();
    }

    expect(find.text('Тренировать'), findsOneWidget);
    await tester.tap(find.text('Тренировать'));
    await tester.pump();

    expect(recorded, isNotNull);
    expect(recorded!.total, 11);
    expect(recorded!.correct, 11);
    expect(recorded!.status, isNot(CompetencyStatus.mastered));
  });
}
