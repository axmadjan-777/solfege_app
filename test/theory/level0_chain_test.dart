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

  testWidgets('L00-01 plays the authored steps and does not grant mastered', (tester) async {
    final plan = Level0Plan.fromLesson(catalog.lesson('L00-01'));
    Level0Result? result;
    await tester.pumpWidget(
      MaterialApp(home: Level0Player(plan: plan, onFinished: (value) => result = value)),
    );

    expect(find.text(plan.steps.first.body), findsOneWidget);
    await _tap(tester, find.text('Дальше'));

    for (final step in plan.steps.where((step) => !step.isExplanation)) {
      expect(find.text(step.body), findsOneWidget);
      if (step.templateId == 'T03') {
        for (final index in step.correctIndexes) {
          await _tap(tester, find.widgetWithText(CheckboxListTile, step.options[index]));
        }
        await _tap(tester, find.text('Проверить'));
      } else {
        await _tap(tester, find.text(step.options[step.correctIndex]));
      }
      await _tap(tester, find.text('Дальше'));
    }

    expect(find.text('Тренировать'), findsOneWidget);
    await _tap(tester, find.text('Тренировать'));

    expect(result, isNotNull);
    expect(result!.status, isNot(CompetencyStatus.mastered));
    expect(result!.correct, result!.total);
  });

  testWidgets('L00-02 is closed on the theory list until L00-01 is mastered', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TheoryHomeScreen(catalog: catalog)),
    );

    expect(find.text('Музыкальный тон и шум'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('lesson-L00-01')), matching: find.text('Открыто')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(const Key('lesson-L00-02')), matching: find.text('Закрыто')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TheoryHomeScreen(catalog: catalog, isMastered: (id) => id == 'snd.tone_vs_noise'),
      ),
    );
    expect(
      find.descendant(of: find.byKey(const Key('lesson-L00-02')), matching: find.text('Открыто')),
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

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
