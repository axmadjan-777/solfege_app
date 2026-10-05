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
  test('a minor third is a semitone lower than a major third', () {
    final lesson = _catalog().lesson('L06-01');
    final plan = Level0Plan.fromLesson(lesson);
    expect(plan.steps[1].options, ['мажор', 'минор']);
    expect(plan.steps[1].correctIndex, 0);
    expect(plan.steps[2].correctIndex, 1);
    expect(plan.steps.last.correctIndex, 1);
    expect(statusAfterLesson(), CompetencyStatus.provisionallyPassed);
    expect(statusAfterLesson(), isNot(CompetencyStatus.mastered));
  });

  testWidgets('L06-01 plays and keeps the natural-minor lesson closed',
      (tester) async {
    final catalog = _catalog();
    final lesson = catalog.lesson('L06-01');
    final plan = Level0Plan.fromLesson(lesson);
    expect(plan.steps.first.body, lesson.plainExplanation);
    expect(plan.trainPracticeSetIds, contains('PR-05'));

    Level0Result? result;
    await tester.pumpWidget(MaterialApp(
        home: Level0Player(plan: plan, onFinished: (value) => result = value)));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('мажор'));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('минор'));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('ниже'));
    await _tap(tester, find.text('Дальше'));
    expect(find.text('Тренировать'), findsOneWidget);
    await _tap(tester, find.text('Тренировать'));
    expect(result?.status, isNot(CompetencyStatus.mastered));

    await tester.pumpWidget(
      MaterialApp(
        home: TheoryHomeScreen(
          catalog: catalog,
          isMastered: (id) => id == 'int.thirds' || id == 'sca.degree_numbers',
        ),
      ),
    );
    await tester.scrollUntilVisible(
        find.byKey(const Key('lesson-L05-05')), 400);
    expect(
      find.descendant(
          of: find.byKey(const Key('lesson-L05-05')),
          matching: find.text('Закрыто')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
        find.text('Мажор и минор: разница третьей ступени'), 400);
    expect(
      find.descendant(
          of: find.byKey(const Key('lesson-L06-01')),
          matching: find.text('Открыто')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Натуральный минор'), 400);
    expect(
      find.descendant(
          of: find.byKey(const Key('lesson-L06-02')),
          matching: find.text('Закрыто')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
        find.byKey(const Key('lesson-L07-01')), 400);
    expect(
      find.descendant(
          of: find.byKey(const Key('lesson-L07-01')),
          matching: find.text('Закрыто')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
        find.byKey(const Key('lesson-L11-01')), 400);
    expect(
      find.descendant(
          of: find.byKey(const Key('lesson-L11-01')),
          matching: find.text('Закрыто')),
      findsOneWidget,
    );
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

CurriculumCatalog _catalog() {
  Map<String, dynamic> read(String name) {
    return Map<String, dynamic>.from(
        jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
  }

  return CurriculumCatalog.fromDecoded(
    levels: read('levels.json'),
    sourceMap: read('source-map.json'),
    audioManifest: read('audio-manifest.json'),
    exercises: read('exercises.json'),
    competencies: read('competencies.json'),
    lessons: read('lessons.json'),
  );
}
