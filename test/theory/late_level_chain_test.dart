import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/theory/level0/level0_plan.dart';
import 'package:solfege_app/features/theory/level0/level0_player.dart';
import 'package:solfege_app/features/theory/screens/theory_home_screen.dart';

void main() {
  late CurriculumCatalog catalog;

  setUpAll(() {
    catalog = CurriculumCatalog.fromDecoded(
      levels: _read('levels.json'),
      sourceMap: _read('source-map.json'),
      audioManifest: _read('audio-manifest.json'),
      exercises: _read('exercises.json'),
      competencies: _read('competencies.json'),
      lessons: _read('lessons.json'),
    );
  });

  testWidgets('L07-01 stays closed until eighths are mastered, then plays',
      (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: TheoryHomeScreen(catalog: catalog)));
    await tester.scrollUntilVisible(
        find.byKey(const Key('lesson-L07-01')), 400);
    expect(
      find.descendant(
          of: find.byKey(const Key('lesson-L07-01')),
          matching: find.text('Закрыто')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TheoryHomeScreen(
            catalog: catalog, isMastered: (id) => id == 'rhy.eighths'),
      ),
    );
    await tester.scrollUntilVisible(
        find.byKey(const Key('lesson-L07-01')), 400);
    expect(
      find.descendant(
          of: find.byKey(const Key('lesson-L07-01')),
          matching: find.text('Открыто')),
      findsOneWidget,
    );
    await _tap(tester, find.text('Шестнадцатые'));
    await tester.pumpAndSettle();

    expect(find.text('Дальше'), findsOneWidget);
    await _play(tester, Level0Plan.fromLesson(catalog.lesson('L07-01')));
  });

  testWidgets(
      'L06-05 and L11-02 accept the musical answer and do not grant mastered',
      (tester) async {
    for (final id in ['L06-05', 'L09-04', 'L11-02']) {
      final plan = Level0Plan.fromLesson(catalog.lesson(id));
      Level0Result? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Level0Player(
            key: ValueKey(id),
            plan: plan,
            onFinished: (value) => result = value,
          ),
        ),
      );
      await _play(tester, plan);
      expect(result?.lessonId, id);
      expect(result?.correct, result?.total);
      expect(result?.status, isNot(CompetencyStatus.mastered));
      expect(result?.status, CompetencyStatus.provisionallyPassed);
    }
  });

  testWidgets(
      'a wrong answer on L07-01 shows the card error and still caps the status',
      (tester) async {
    final plan = Level0Plan.fromLesson(catalog.lesson('L07-01'));
    Level0Result? result;
    await tester.pumpWidget(
      MaterialApp(
          home:
              Level0Player(plan: plan, onFinished: (value) => result = value)),
    );
    await _tap(tester, find.text('Дальше'));
    final step = plan.steps[1];
    await _tap(tester, find.text(step.options[1]));
    expect(find.text(step.feedbackError), findsOneWidget);
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text(plan.steps.last.options[1]));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('Тренировать'));
    expect(result?.correct, 0);
    expect(result?.total, 2);
    expect(result?.status, CompetencyStatus.provisionallyPassed);
  });
}

Future<void> _play(WidgetTester tester, Level0Plan plan) async {
  if (find.text('Дальше').evaluate().isEmpty) {
    expect(find.text(plan.steps.first.body), findsOneWidget);
  }
  await _tap(tester, find.text('Дальше'));
  for (final step in plan.steps.where((step) => !step.isExplanation)) {
    expect(find.text(step.body), findsOneWidget);
    await _tap(tester, find.text(step.options[step.correctIndex]));
    await _tap(tester, find.text('Дальше'));
  }
  expect(find.text('Тренировать'), findsOneWidget);
  await _tap(tester, find.text('Тренировать'));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(
      jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
