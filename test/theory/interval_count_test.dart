import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/screens/practice_map_screen.dart';
import 'package:solfege_app/features/practice/trainers/interval_count.dart';
import 'package:solfege_app/features/theory/level0/level0_plan.dart';
import 'package:solfege_app/features/theory/level0/level0_player.dart';

void main() {
  test('a fourth covers 4 degrees, including both ends', () {
    expect(degreeSpan(1, 4), 4);
    expect(degreeSpan(1, 3), 3);
    expect(degreeSpan(1, 4), isNot(3));
    expect(pr04EarlyStage(1), isTrue);
    expect(pr04EarlyStage(3), isFalse);
  });

  testWidgets('L05-01 plays and keeps PR-04 closed until the count is mastered', (tester) async {
    final catalog = _catalog();
    final lesson = catalog.lesson('L05-01');
    final plan = Level0Plan.fromLesson(lesson);
    expect(plan.steps.first.body, lesson.plainExplanation);

    await tester.pumpWidget(MaterialApp(home: Level0Player(plan: plan, onFinished: (_) {})));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('3'));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('4'));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('4'));
    await _tap(tester, find.text('Дальше'));
    expect(find.text('Тренировать'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: PracticeMapScreen(catalog: catalog)));
    await tester.scrollUntilVisible(find.text('Интервалы: построение'), 500);
    expect(
      find.descendant(of: find.byKey(const Key('practice-PR-04')), matching: find.text('Закрыто')),
      findsOneWidget,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeMapScreen(catalog: catalog, isMastered: (id) => id == 'int.number'),
      ),
    );
    await tester.scrollUntilVisible(find.text('Интервалы: построение'), 500);
    expect(
      find.descendant(of: find.byKey(const Key('practice-PR-04')), matching: find.text('Открыто')),
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
    return Map<String, dynamic>.from(jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
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
