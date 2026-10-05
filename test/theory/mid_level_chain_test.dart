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

  testWidgets('L08-01 stays closed until thirds are mastered, then plays',
      (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: TheoryHomeScreen(catalog: catalog)));
    await tester.scrollUntilVisible(
        find.byKey(const Key('lesson-L08-01')), 400);
    expect(
      find.descendant(
          of: find.byKey(const Key('lesson-L08-01')),
          matching: find.text('Закрыто')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TheoryHomeScreen(
            catalog: catalog, isMastered: (id) => id == 'int.thirds'),
      ),
    );
    await tester.scrollUntilVisible(
        find.byKey(const Key('lesson-L08-01')), 400);
    expect(
      find.descendant(
          of: find.byKey(const Key('lesson-L08-01')),
          matching: find.text('Открыто')),
      findsOneWidget,
    );
    await _tap(tester, find.text('Трезвучие как две терции'));
    await tester.pumpAndSettle();
    await _play(tester, Level0Plan.fromLesson(catalog.lesson('L08-01')));
  });

  testWidgets('interval, triad and reading lessons do not grant mastered',
      (tester) async {
    for (final id in ['L05-09', 'L08-08', 'L10-07']) {
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
      expect(result?.status, CompetencyStatus.provisionallyPassed);
    }
  });
}

Future<void> _play(WidgetTester tester, Level0Plan plan) async {
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
